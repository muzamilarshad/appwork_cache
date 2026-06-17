defmodule AppworkCache.Upstreams.UserStore do
  @moduledoc """
  Simulated slow user database backed by ETS.

  Seeds `users/1` through `users/10` at startup. Each fetch sleeps to mimic
  a slow query and increments `call_count/0` only on successful lookups.
  """

  @behaviour AppworkCache.Upstream

  use GenServer

  alias AppworkCache.{Request, Response}

  @default_sleep_ms 50
  @user_count 10

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
    table = Keyword.get(opts, :table, __MODULE__.Table)
    table = if is_atom(table), do: table, else: table

    if is_atom(table) do
      :ets.new(table, [:named_table, :protected, read_concurrency: true])
      seed_users(table)
    end

    {:ok,
     %{
       table: table,
       sleep_ms: Keyword.get(opts, :sleep_ms, @default_sleep_ms),
       call_count: 0
     }}
  end

  @impl true
  def handle_call({:fetch, %Request{id: id}}, _from, state) do
    case :ets.lookup(state.table, id) do
      [{^id, user}] ->
        if state.sleep_ms > 0, do: Process.sleep(state.sleep_ms)

        response = %Response{body: user}
        state = %{state | call_count: state.call_count + 1}

        {:reply, {:ok, response}, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:call_count, _from, state) do
    {:reply, state.call_count, state}
  end

  defp seed_users(table) do
    for n <- 1..@user_count do
      id = "users/#{n}"
      :ets.insert(table, {id, %{id: id, name: "User #{n}", email: "user#{n}@example.com"}})
    end
  end
end
