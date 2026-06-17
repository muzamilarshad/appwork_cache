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
  """
  @spec ttl(t()) :: pos_integer()
  def ttl(%__MODULE__{ttl_seconds: seconds})
      when is_integer(seconds) and seconds > 0 do
    seconds
  end
end
