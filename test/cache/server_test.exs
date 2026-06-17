defmodule AppworkCache.Cache.ServerTest do
  use ExUnit.Case, async: false

  alias AppworkCache.Cache.Server
  alias AppworkCache.Request
  alias AppworkCache.Upstreams.UserStore

  setup do
    UserStore.stop()
    Server.stop()

    {:ok, _upstream} = UserStore.start_link(sleep_ms: 0)
    {:ok, _cache} = Server.start_link(cap: 2, upstream: UserStore)

    on_exit(fn ->
      Server.stop()
      UserStore.stop()
    end)

    :ok
  end

  defp req(id), do: %Request{id: id}

  describe "fetch/1" do
    test "cache hit avoids upstream on repeated request" do
      assert {:ok, _} = Server.fetch(req("users/1"))
      assert {:ok, _} = Server.fetch(req("users/1"))

      assert UserStore.call_count() == 1
    end

    test "cache miss calls upstream for distinct requests" do
      assert {:ok, _} = Server.fetch(req("users/1"))
      assert {:ok, _} = Server.fetch(req("users/2"))

      assert UserStore.call_count() == 2
    end

    test "LRU eviction removes least recently used entry when capacity exceeded" do
      assert {:ok, _} = Server.fetch(req("users/1"))
      assert {:ok, _} = Server.fetch(req("users/2"))
      assert {:ok, _} = Server.fetch(req("users/3"))

      assert UserStore.call_count() == 3

      # users/1 was LRU among distinct keys after users/3 was inserted.
      assert {:ok, _} = Server.fetch(req("users/1"))
      assert UserStore.call_count() == 4
    end

    test "cache hit promotes entry in LRU order" do
      assert {:ok, _} = Server.fetch(req("users/1"))
      assert {:ok, _} = Server.fetch(req("users/2"))
      assert UserStore.call_count() == 2

      # Hit promotes users/1 to MRU.
      assert {:ok, _} = Server.fetch(req("users/1"))
      assert UserStore.call_count() == 2

      # users/3 evicts LRU users/2, not users/1.
      assert {:ok, _} = Server.fetch(req("users/3"))
      assert UserStore.call_count() == 3

      # users/1 still cached; promote again before users/2 returns.
      assert {:ok, _} = Server.fetch(req("users/1"))
      assert UserStore.call_count() == 3

      assert {:ok, _} = Server.fetch(req("users/2"))
      assert UserStore.call_count() == 4

      assert {:ok, _} = Server.fetch(req("users/1"))
      assert UserStore.call_count() == 4
    end

    test "does not cache upstream errors" do
      unknown = req("users/999")

      assert {:error, :not_found} = Server.fetch(unknown)
      assert {:error, :not_found} = Server.fetch(unknown)

      assert UserStore.request_count() == 2
      assert UserStore.call_count() == 0
    end

    test "concurrent fetches for the same request call upstream once" do
      request = req("users/5")

      task_count = 20

      results =
        1..task_count
        |> Task.async_stream(fn _ -> Server.fetch(request) end, timeout: :infinity)
        |> Enum.map(fn {:ok, result} -> result end)

      assert length(results) == task_count
      assert Enum.all?(results, &match?({:ok, _}, &1))
      assert UserStore.call_count() == 1
    end
  end
end
