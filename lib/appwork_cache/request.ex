defmodule AppworkCache.Request do
  @moduledoc """
  Cache key struct. `hash/1` provides a stable integer for lookup and comparison.
  """

  @type t :: %__MODULE__{id: String.t()}

  defstruct [:id]

  @doc """
  Returns a stable integer hash for the request.

  Uses `:erlang.phash2/1` on `id` for efficient comparison in tests and cache storage.
  """
  @spec hash(t()) :: non_neg_integer()
  def hash(%__MODULE__{id: id}), do: :erlang.phash2(id)
end
