defmodule AppworkCache.Cache.Entry do
  @moduledoc """
  A cached response with expiration metadata.

  The cache stores entries in ETS (`{hash, %Entry{}}`), not raw responses alone.
  """

  alias AppworkCache.Response

  @type t :: %__MODULE__{
          response: Response.t(),
          expires_at: DateTime.t()
        }

  defstruct [:response, :expires_at]

  @doc """
  Builds an entry from a response, computing `expires_at` from `Response.ttl/1`.
  """
  @spec new(Response.t(), DateTime.t()) :: t()
  def new(%Response{} = response, %DateTime{} = now) do
    %__MODULE__{
      response: response,
      expires_at: DateTime.add(now, Response.ttl(response), :second)
    }
  end

  @doc """
  Returns true when the entry is still valid at `now`.
  """
  @spec valid?(t(), DateTime.t()) :: boolean()
  def valid?(%__MODULE__{expires_at: expires_at}, %DateTime{} = now) do
    DateTime.compare(expires_at, now) == :gt
  end
end
