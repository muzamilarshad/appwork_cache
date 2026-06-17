defmodule AppworkCache.Upstreams.UserStore do
  @moduledoc """
  Simulated slow user database backed by ETS.

  Seeds `users/1` through `users/10` at startup. Each user has a distinct
  `ttl_seconds` (e.g. `users/1` → 1s for expiry tests, `users/2` → 300s).
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

  @impl AppworkCache.Upstream
  def fetch(%Request{} = request) do
    GenServer.call(__MODULE__, {:fetch, request})
  end

  def call_count(name \\ __MODULE__) do
    GenServer.call(name, :call_count)
  end

  def request_count(name \\ __MODULE__) do
    GenServer.call(name, :request_count)
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
       call_count: 0,
       request_count: 0
     }}
  end

  @impl true
  def handle_call({:fetch, %Request{id: id}}, _from, state) do
    state = %{state | request_count: state.request_count + 1}

    case :ets.lookup(state.table, id) do
      [{^id, user}] ->
        if state.sleep_ms > 0, do: Process.sleep(state.sleep_ms)

        response = %Response{body: user, ttl_seconds: user.ttl_seconds}
        state = %{state | call_count: state.call_count + 1}

        {:reply, {:ok, response}, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:call_count, _from, state) do
    {:reply, state.call_count, state}
  end

  def handle_call(:request_count, _from, state) do
    {:reply, state.request_count, state}
  end

  defp seed_users(table) do
    for n <- 1..@user_count do
      id = "users/#{n}"

      user = %{
        id: id,
        name: "User #{n}",
        email: "user#{n}@example.com",
        ttl_seconds: ttl_for(n)
      }

      :ets.insert(table, {id, user})
    end
  end

  defp ttl_for(1), do: 1
  defp ttl_for(2), do: 300
  defp ttl_for(3), do: 60
  defp ttl_for(4), do: 120
  defp ttl_for(5), do: 30
  defp ttl_for(6), do: 180
  defp ttl_for(7), do: 90
  defp ttl_for(8), do: 240
  defp ttl_for(9), do: 45
  defp ttl_for(10), do: 600
end
