defmodule AppworkCache.Response do
  @moduledoc """
  Value stored in the cache. TTL support is added in V3.
  """

  @type t :: %__MODULE__{body: term()}

  defstruct [:body]
end
