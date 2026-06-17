defmodule AppworkCache.Application do
  @moduledoc """
  OTP application entry point.

  Starts the default upstream (`UserStore`) and a `Cache.Server` under a
  one-for-one supervisor. Cache capacity defaults to 100 and can be overridden
  via application config:

      config :appwork_cache, cap: 200
  """

  use Application

  @default_cap 100

  @impl true
  def start(_type, _args) do
    cap = Application.get_env(:appwork_cache, :cap, @default_cap)
    start_children? = Application.get_env(:appwork_cache, :start_children, true)

    children =
      if start_children? do
        [
          AppworkCache.Upstreams.UserStore,
          {AppworkCache.Cache.Server, cap: cap, upstream: AppworkCache.Upstreams.UserStore}
        ]
      else
        []
      end

    opts = [strategy: :one_for_one, name: AppworkCache.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
