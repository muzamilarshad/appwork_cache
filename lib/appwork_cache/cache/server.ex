defmodule AppworkCache.Cache.Server do
  @moduledoc """
  V2 LRU capped cache with ETS-backed concurrent reads.

  Cache hits read ETS directly, then promote the entry via a synchronous
  GenServer touch. Misses are coordinated through this GenServer, which calls
  upstream and evicts the least recently used distinct key when capacity is exceeded.
  """

  @behaviour AppworkCache.Cache

  use GenServer

  alias AppworkCache.Cache.LRU
  alias AppworkCache.{Request, Response}

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def stop(name \\ __MODULE__) do
    case Process.whereis(name) do
      nil ->
        :ok

      pid ->
        try do
          GenServer.stop(pid)
        catch
          :exit, _ -> :ok
        end
    end
  end

  @impl AppworkCache.Cache
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @impl AppworkCache.Cache
  def fetch(%Request{} = request) do
    name = __MODULE__
    table = table_name(name)
    hash = Request.hash(request)

    case :ets.lookup(table, hash) do
      [{^hash, %Response{} = response}] ->
        :ok = GenServer.call(name, {:touch, hash})
        {:ok, response}

      [] ->
        GenServer.call(name, {:fetch, request, hash})
    end
  end

  @impl true
  def init(opts) do
    cap = Keyword.fetch!(opts, :cap)
    upstream = Keyword.fetch!(opts, :upstream)
    name = Keyword.get(opts, :name, __MODULE__)
    table = Keyword.get(opts, :table, table_name(name))

    if is_atom(table) do
      :ets.new(table, [:named_table, :protected, read_concurrency: true])
    end

    {:ok, %{cap: cap, upstream: upstream, table: table, queue: []}}
  end

  @impl true
  def handle_call({:touch, hash}, _from, state) do
    {:reply, :ok, %{state | queue: LRU.touch(state.queue, hash)}}
  end

  @impl true
  def handle_call({:fetch, request, hash}, _from, state) do
    case :ets.lookup(state.table, hash) do
      [{^hash, %Response{} = response}] ->
        {:reply, {:ok, response}, %{state | queue: LRU.touch(state.queue, hash)}}

      [] ->
        case state.upstream.fetch(request) do
          {:error, _} = error ->
            {:reply, error, state}

          {:ok, %Response{} = response} ->
            :ets.insert(state.table, {hash, response})

            {:ok, queue, evicted} = LRU.insert(state.queue, hash, state.cap)

            if evicted do
              :ets.delete(state.table, evicted)
            end

            {:reply, {:ok, response}, %{state | queue: queue}}
        end
    end
  end

  defp table_name(name) when is_atom(name), do: :"#{name}.Entries"
end
