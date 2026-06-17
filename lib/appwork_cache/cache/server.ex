defmodule AppworkCache.Cache.Server do
  @moduledoc """
  V1 FIFO capped cache with ETS-backed concurrent reads.

  Cache hits read ETS directly. Misses are coordinated through this GenServer,
  which calls upstream and evicts the oldest entry when capacity is exceeded.
  """

  @behaviour AppworkCache.Cache

  use GenServer

  alias AppworkCache.{Request, Response}

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def stop(name \\ __MODULE__) do
    case Process.whereis(name) do
      nil -> :ok
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
  def handle_call({:fetch, request, hash}, _from, state) do
    case :ets.lookup(state.table, hash) do
      [{^hash, %Response{} = response}] ->
        {:reply, {:ok, response}, state}

      [] ->
        case state.upstream.fetch(request) do
          {:error, _} = error ->
            {:reply, error, state}

          {:ok, %Response{} = response} ->
            :ets.insert(state.table, {hash, response})
            state = evict_if_needed(%{state | queue: state.queue ++ [hash]})
            {:reply, {:ok, response}, state}
        end
    end
  end

  defp evict_if_needed(%{cap: cap, queue: queue} = state) when length(queue) <= cap, do: state

  defp evict_if_needed(%{table: table, queue: [oldest | rest]} = state) do
    :ets.delete(table, oldest)
    %{state | queue: rest}
  end

  defp table_name(name) when is_atom(name), do: :"#{name}.Entries"
end
