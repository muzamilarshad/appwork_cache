defmodule AppworkCache.Upstreams.SlowUpstream do
  @moduledoc """
  Test-only GenServer that simulates a slow upstream service.

  Sleeps on each fetch and tracks `call_count/0` so tests can verify the cache
  avoids calling upstream on hits.
  """

  @behaviour AppworkCache.Upstream

  use GenServer

  alias AppworkCache.{Request, Response}

  @default_sleep_ms 50

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def stop(name \\ __MODULE__) do
    case Process.whereis(name) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end

  @impl AppworkCache.Upstream
  def fetch(%Request{} = request) do
    GenServer.call(__MODULE__, {:fetch, request})
  end

  def call_count(name \\ __MODULE__) do
    GenServer.call(name, :call_count)
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       sleep_ms: Keyword.get(opts, :sleep_ms, @default_sleep_ms),
       call_count: 0
     }}
  end

  @impl true
  def handle_call({:fetch, %Request{id: id}}, _from, state) do
    if state.sleep_ms > 0, do: Process.sleep(state.sleep_ms)

    response = %Response{body: %{id: id, source: :upstream}}
    state = %{state | call_count: state.call_count + 1}

    {:reply, response, state}
  end

  def handle_call(:call_count, _from, state) do
    {:reply, state.call_count, state}
  end
end
