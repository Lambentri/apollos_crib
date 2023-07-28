defmodule Unzip.InMem do
  defstruct [:blob]
  alias __MODULE__

  def new(blob) do
    %Unzip.InMem{blob: blob}
  end
end

defimpl Unzip.FileAccess, for: Unzip.InMem do
  def size(file) do
    {:ok, file.blob |> byte_size}
  end

  def pread(file, offset, length) do
    {:ok, file.blob |> binary_part(offset, length)}
  end
end