defmodule AppworkCache.Cache do
  @moduledoc """
  Behaviour for a concurrent cache that wraps an upstream service.

  Exposes the same `fetch(request) -> response` interface as upstream.
  Implementations must be safe when many processes call `fetch/1` concurrently.
  On a cache miss, the implementation fetches from upstream and stores the result.

  The cache process (e.g. a GenServer) is started via `child_spec/1` and is not
  passed into `fetch/1` — matching the assignment's identical interface.
  """

  @type request :: term()
  @type response :: term()

  @callback child_spec(keyword()) :: Supervisor.child_spec()

  @callback fetch(request()) :: response()
end
