defmodule AppworkCache.UpstreamTest do
  use ExUnit.Case, async: false

  alias AppworkCache.Request
  alias AppworkCache.Upstreams.SlowUpstream

  setup do
    SlowUpstream.stop()
    {:ok, _pid} = SlowUpstream.start_link(sleep_ms: 30)

    on_exit(fn -> SlowUpstream.stop() end)

    :ok
  end

  describe "fetch/1" do
    test "returns a response derived from the request id" do
      req = %Request{id: "users/42"}

      assert %{body: %{id: "users/42", source: :upstream}} = SlowUpstream.fetch(req)
    end

    test "increments call_count on each fetch" do
      req = %Request{id: "users/42"}

      assert SlowUpstream.call_count() == 0

      SlowUpstream.fetch(req)
      assert SlowUpstream.call_count() == 1

      SlowUpstream.fetch(req)
      assert SlowUpstream.call_count() == 2
    end

    test "sleeps to simulate a slow upstream" do
      req = %Request{id: "users/42"}

      {elapsed_us, _} = :timer.tc(fn -> SlowUpstream.fetch(req) end)

      assert elapsed_us >= 25_000
    end
  end
end
