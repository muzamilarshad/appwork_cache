defmodule AppworkCache.Upstream do
  @moduledoc """
  Behaviour for the slow upstream service the cache wraps.

  The cache calls upstream only on a miss. Both expose the same
  `fetch(request)` contract, returning `{:ok, response}` or `{:error, term}`.
  """

  alias AppworkCache.{Request, Response}

  @type request :: Request.t()
  @type fetch_result :: {:ok, Response.t()} | {:error, term()}

  @callback fetch(request()) :: fetch_result()
end
