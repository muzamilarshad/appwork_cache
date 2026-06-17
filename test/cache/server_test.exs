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

    test "cache hit within TTL avoids upstream" do
      assert {:ok, _} = Server.fetch(req("users/2"))
      assert {:ok, _} = Server.fetch(req("users/2"))

      assert UserStore.call_count() == 1
    end

    test "expired entry refetches from upstream" do
      assert {:ok, _} = Server.fetch(req("users/1"))
      assert UserStore.call_count() == 1

      Process.sleep(1_100)

      assert {:ok, _} = Server.fetch(req("users/1"))
      assert UserStore.call_count() == 2
    end

    test "expired entry is removed from cache on fetch" do
      assert {:ok, _} = Server.fetch(req("users/1"))

      Process.sleep(1_100)

      assert {:ok, _} = Server.fetch(req("users/1"))
      assert {:ok, _} = Server.fetch(req("users/1"))

      assert UserStore.call_count() == 2
    end

    test "stale touch does not create a ghost that lets cache exceed capacity" do
      # Fill to cap=2: queue=[u1, u2], ETS={u1, u2}
      assert {:ok, _} = Server.fetch(req("users/1"))
      assert {:ok, _} = Server.fetch(req("users/2"))

      # Evict u1: queue=[u2, u3], ETS={u2, u3}
      assert {:ok, _} = Server.fetch(req("users/3"))

      # Simulate a late touch for u1 arriving after it was already evicted.
      # Without the fix, LRU.touch appends u1's hash back as a ghost:
      #   queue=[u2, u3, ghost_u1], length 3 > cap 2
      # With the fix, ets.member returns false so the queue is unchanged:
      #   queue=[u2, u3], length 2
      :ok = GenServer.call(AppworkCache.Cache.Server, {:touch, Request.hash(req("users/1"))})

      # Three more misses drive the ghost toward the LRU position and eventually
      # evict it. When the ghost is evicted, ets.delete is a no-op so the entry
      # just inserted is NOT displaced — the cache silently holds cap+1=3 entries.
      #
      # Without fix:
      #   fetch u4: evict u2     → queue=[u3, ghost, u4], ETS={u3, u4}
      #   fetch u5: evict u3     → queue=[ghost, u4, u5], ETS={u4, u5}
      #   fetch u6: evict ghost  → ets.delete(ghost)=noop, ETS grows to {u4,u5,u6}!
      #
      # With fix:
      #   fetch u4: evict u2 → queue=[u3, u4], ETS={u3, u4}
      #   fetch u5: evict u3 → queue=[u4, u5], ETS={u4, u5}
      #   fetch u6: evict u4 → queue=[u5, u6], ETS={u5, u6}
      assert {:ok, _} = Server.fetch(req("users/4"))
      assert {:ok, _} = Server.fetch(req("users/5"))
      assert {:ok, _} = Server.fetch(req("users/6"))

      upstream_calls_before = UserStore.call_count()

      # With fix: u4 was properly evicted → this is a miss (+1 upstream call).
      # Without fix: ghost was evicted instead of u4 → u4 is still live → hit (0 calls).
      Server.fetch(req("users/4"))

      assert UserStore.call_count() == upstream_calls_before + 1
    end
  end
end
