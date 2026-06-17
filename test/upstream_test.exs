defmodule AppworkCache.UpstreamTest do
  use ExUnit.Case, async: false

  alias AppworkCache.{Request, Response}
  alias AppworkCache.Upstreams.UserStore

  setup do
    UserStore.stop()
    {:ok, _pid} = UserStore.start_link(sleep_ms: 30)

    on_exit(fn -> UserStore.stop() end)

    :ok
  end

  describe "fetch/1" do
    test "returns a seeded user for a known id" do
      req = %Request{id: "users/1"}

      assert {:ok, %Response{body: %{id: "users/1", name: "User 1", email: "user1@example.com"}, ttl_seconds: 1}} =
               UserStore.fetch(req)
    end

    test "returns not_found for an unknown id" do
      req = %Request{id: "users/999"}

      assert {:error, :not_found} = UserStore.fetch(req)
    end

    test "increments call_count only on successful fetches" do
      known = %Request{id: "users/1"}
      unknown = %Request{id: "users/999"}

      assert UserStore.call_count() == 0

      assert {:ok, _} = UserStore.fetch(known)
      assert UserStore.call_count() == 1

      assert {:error, :not_found} = UserStore.fetch(unknown)
      assert UserStore.call_count() == 1

      assert {:ok, _} = UserStore.fetch(known)
      assert UserStore.call_count() == 2
    end

    test "sleeps to simulate a slow upstream for known users" do
      req = %Request{id: "users/1"}

      {elapsed_us, {:ok, _}} = :timer.tc(fn -> UserStore.fetch(req) end)

      assert elapsed_us >= 25_000
    end
  end
end
