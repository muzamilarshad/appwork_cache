defmodule AppworkCache do
  @moduledoc """
  LRU + TTL cache that wraps a slow upstream with `fetch(request) -> response`.

  See `AppworkCache.Cache`, `AppworkCache.Upstream`, `AppworkCache.Request`,
  and `AppworkCache.Response` for the V0 interfaces.
  """
end
