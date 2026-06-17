defmodule AppworkCache.Response do
  @moduledoc """
  Value stored in the cache. Includes a per-response TTL in seconds.
  """

  @type t :: %__MODULE__{
          body: term(),
          ttl_seconds: pos_integer()
        }

  defstruct [:body, :ttl_seconds]

  @doc """
  Returns the TTL in seconds for this response.

  Raises `ArgumentError` if `ttl_seconds` is not a positive integer.
  """
  @spec ttl(t()) :: pos_integer()
  def ttl(%__MODULE__{ttl_seconds: seconds})
      when is_integer(seconds) and seconds > 0,
      do: seconds

  def ttl(%__MODULE__{ttl_seconds: bad}) do
    raise ArgumentError,
          "ttl_seconds must be a positive integer, got: #{inspect(bad)}"
  end
end
