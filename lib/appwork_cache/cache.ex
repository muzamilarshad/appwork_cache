defmodule AppworkCache.Cache do
  @moduledoc """
  Behaviour for a concurrent cache that wraps an upstream service.

  Exposes the same `fetch(request)` contract as upstream, returning
  `{:ok, response}` on success or `{:error, term}` on failure.

  Implementations must be safe when many processes call `fetch/1` concurrently.
  On a cache miss, the implementation fetches from upstream and stores successful
  results only.

  The cache process (e.g. a GenServer) is started via `child_spec/1` and is not
  passed into `fetch/1` — matching the assignment's identical interface.
  """

  alias AppworkCache.{Request, Response}

  @type request :: Request.t()
  @type fetch_result :: {:ok, Response.t()} | {:error, term()}

  @callback child_spec(keyword()) :: Supervisor.child_spec()

  @callback fetch(request()) :: fetch_result()
end
