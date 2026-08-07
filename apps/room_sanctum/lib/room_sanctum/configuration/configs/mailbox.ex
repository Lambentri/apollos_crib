defmodule RoomSanctum.Configuration.Configs.Mailbox do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  An IMAP account, as a source in its own right.

  Kept separate from the things that consume it so one account can feed several
  consumers -- a packages source points at a mailbox by id rather than carrying
  its own copy of the credentials.
  """

  embedded_schema do
    field :host, :string
    field :port, :integer, default: 993
    field :username, :string
    field :password, :string
    field :tls, :boolean, default: true
    field :folder, :string, default: "INBOX"
  end

  def changeset(source, params) do
    source
    |> cast(params, [:host, :port, :username, :password, :tls, :folder])
    |> keep_existing_password()
    |> validate_required([:host, :username, :port, :folder])
    |> validate_number(:port, greater_than: 0, less_than: 65_536)
    |> validate_password_present()
  end

  @doc "The connection map the IMAP client expects."
  def connection(%__MODULE__{} = c) do
    %{
      host: c.host,
      port: c.port || 993,
      tls: c.tls != false,
      username: c.username,
      password: c.password,
      folder: c.folder || "INBOX"
    }
  end

  def connection(_), do: nil

  # The form never renders a stored password back into the page, so a blank
  # submission means "unchanged" rather than "clear it".
  defp keep_existing_password(changeset) do
    case {get_change(changeset, :password), changeset.data.password} do
      {blank, existing} when blank in ["", nil] and is_binary(existing) and existing != "" ->
        delete_change(changeset, :password)

      _ ->
        changeset
    end
  end

  defp validate_password_present(changeset) do
    if get_field(changeset, :password) in [nil, ""] do
      add_error(changeset, :password, "can't be blank")
    else
      changeset
    end
  end
end
