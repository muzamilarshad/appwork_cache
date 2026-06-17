defmodule AppworkCache.Upstream do
  @moduledoc """
  Behaviour for the slow upstream service the cache wraps.

  The cache calls upstream only on a miss. Both expose the same
  `fetch(request) -> response` contract.
  """

  @type request :: term()
  @type response :: term()

  @callback fetch(request()) :: response()
end
