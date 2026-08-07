defmodule RoomHermes.Mail.Headers do
  @moduledoc """
  Just enough header parsing for a message list.

  The full `RoomHermes.Mail.Parser` goes through `:mimemail`, which needs the
  iconv NIF and the whole message body. Listing the latest N messages only wants
  From, Subject and Date, so headers are fetched on their own and parsed here --
  no NIF, and kilobytes instead of megabytes per message.
  """

  @doc """
  Parse a raw header block into a lowercase-keyed map.

  Handles folded headers (continuation lines beginning with whitespace) and
  decodes RFC 2047 encoded-words, which is what stops subject lines rendering as
  `=?UTF-8?B?…?=`.
  """
  def parse(block) when is_binary(block) do
    block
    |> String.split(~r/\r?\n/)
    |> unfold()
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [name, value] ->
          key = name |> String.trim() |> String.downcase()
          Map.put_new(acc, key, value |> String.trim() |> decode_words())

        _ ->
          acc
      end
    end)
  end

  def parse(_), do: %{}

  # A header continues onto the next line when that line starts with space or tab.
  defp unfold(lines) do
    lines
    |> Enum.reduce([], fn
      <<c, _::binary>> = line, [prev | rest] when c in [?\s, ?\t] ->
        [prev <> " " <> String.trim(line) | rest]

      line, acc ->
        if String.trim(line) == "", do: acc, else: [line | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  Decode RFC 2047 encoded-words (`=?UTF-8?B?...?=`).

  Adjacent encoded-words are joined without the separating whitespace, per spec.
  Anything in a charset we cannot handle is left exactly as it arrived rather
  than mangled.
  """
  def decode_words(nil), do: nil

  def decode_words(text) when is_binary(text) do
    Regex.replace(
      ~r/=\?([A-Za-z0-9_\-]+)\?([BbQq])\?([^?]*)\?=(\s+)(?==\?)/,
      text,
      fn _full, charset, enc, data, _ws -> decode_word(charset, enc, data) end
    )
    |> then(fn t ->
      Regex.replace(~r/=\?([A-Za-z0-9_\-]+)\?([BbQq])\?([^?]*)\?=/, t, fn _full, charset, enc, data ->
        decode_word(charset, enc, data)
      end)
    end)
  end

  def decode_words(other), do: other

  defp decode_word(charset, enc, data) do
    decoded =
      case String.upcase(enc) do
        "B" -> Base.decode64(data, padding: false) |> unwrap()
        "Q" -> decode_q(data)
        _ -> nil
      end

    case {decoded, String.upcase(charset)} do
      {nil, _} -> rebuild(charset, enc, data)
      {text, cs} when cs in ["UTF-8", "UTF8", "US-ASCII", "ASCII"] -> ensure_utf8(text, charset, enc, data)
      # latin-1 maps byte-for-byte onto the first 256 codepoints
      {text, cs} when cs in ["ISO-8859-1", "LATIN1"] -> :unicode.characters_to_binary(text, :latin1, :utf8)
      _ -> rebuild(charset, enc, data)
    end
  end

  defp ensure_utf8(text, charset, enc, data) do
    if String.valid?(text), do: text, else: rebuild(charset, enc, data)
  end

  defp rebuild(charset, enc, data), do: "=?#{charset}?#{enc}?#{data}?="

  defp unwrap({:ok, v}), do: v
  defp unwrap(_), do: nil

  # Q-encoding is quoted-printable with underscore standing in for space.
  defp decode_q(data) do
    data
    |> String.replace("_", " ")
    |> then(fn s ->
      Regex.replace(~r/=([0-9A-Fa-f]{2})/, s, fn _, hex ->
        <<String.to_integer(hex, 16)>>
      end)
    end)
  end

  @snippet_length 80

  @doc """
  A short readable preview from the leading bytes of a message body.

  This is a best-effort summary, not a parse. The slice we are handed may begin
  mid-MIME, so it skips past a part boundary and its headers, undoes
  quoted-printable or base64 if that part declared it, and strips tags when the
  part is HTML. Anything it cannot make sense of yields nil rather than a screen
  of boundary markers.
  """
  def snippet(raw, length \\ @snippet_length)
  def snippet(nil, _length), do: nil

  def snippet(raw, length) when is_binary(raw) do
    raw
    |> skip_mime_preamble()
    |> decode_transfer()
    |> strip_html()
    |> collapse()
    |> truncate(length)
    |> case do
      "" -> nil
      text -> text
    end
  end

  def snippet(_, _), do: nil

  # A partial fetch of a multipart message starts at the boundary, so the real
  # text begins after that part's own headers -- i.e. after the first blank line.
  defp skip_mime_preamble(raw) do
    if String.starts_with?(String.trim_leading(raw), "--") do
      case String.split(raw, ~r/\r?\n\r?\n/, parts: 2) do
        [headers, body] -> {cut_at_boundary(body), headers}
        _ -> {raw, ""}
      end
    else
      {raw, ""}
    end
  end

  # The slice usually runs into the *next* boundary. Without this the marker
  # ends up in the preview -- invisible at 24 characters, obvious at 60.
  defp cut_at_boundary(body) do
    body
    |> String.split(~r/\r?\n--/, parts: 2)
    |> hd()
  end

  defp decode_transfer({body, part_headers}) do
    encoding =
      case Regex.run(~r/content-transfer-encoding:\s*([a-z0-9-]+)/i, part_headers) do
        [_, enc] -> String.downcase(enc)
        nil -> nil
      end

    decoded =
      case encoding do
        "quoted-printable" -> decode_qp(body)
        # The slice is unlikely to land on a 4-char boundary, so trim to one.
        "base64" -> decode_partial_base64(body)
        _ -> body
      end

    {decoded, part_headers}
  end

  defp strip_html({body, part_headers}) do
    html? =
      String.match?(part_headers, ~r/content-type:\s*text\/html/i) or
        String.match?(body, ~r/<(html|body|div|p|table)\b/i)

    if html? do
      body
      |> String.replace(~r/<(script|style)\b[^>]*>.*?<\/\1>/is, " ")
      |> String.replace(~r/<[^>]+>/, " ")
      |> unescape_entities()
    else
      body
    end
  end

  defp unescape_entities(text) do
    text
    |> String.replace("&nbsp;", " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
  end

  defp collapse(text) do
    text
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp truncate(text, length) do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end

  defp decode_qp(body) do
    body
    |> String.replace(~r/=\r?\n/, "")
    |> then(fn s ->
      Regex.replace(~r/=([0-9A-Fa-f]{2})/, s, fn _, hex -> <<String.to_integer(hex, 16)>> end)
    end)
  end

  defp decode_partial_base64(body) do
    cleaned = String.replace(body, ~r/\s/, "")
    trimmed = String.slice(cleaned, 0, div(String.length(cleaned), 4) * 4)

    case Base.decode64(trimmed) do
      {:ok, text} -> text
      :error -> ""
    end
  end

  @doc "Strip a display name down to the bare address, if there is one."
  def address(nil), do: nil

  def address(value) when is_binary(value) do
    case Regex.run(~r/<([^>]+)>/, value) do
      [_, email] -> String.trim(email)
      nil -> String.trim(value)
    end
  end

  @doc ~S'Display name from a `"Name" <addr>` header, falling back to the address.'
  def display_name(nil), do: nil

  def display_name(value) when is_binary(value) do
    case String.split(value, "<", parts: 2) do
      [name, _] ->
        cleaned = name |> String.trim() |> String.trim("\"") |> String.trim()
        if cleaned == "", do: address(value), else: cleaned

      _ ->
        address(value)
    end
  end
end
