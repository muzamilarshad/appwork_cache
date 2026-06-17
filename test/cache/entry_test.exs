defmodule AppworkCache.Cache.EntryTest do
  use ExUnit.Case, async: true

  alias AppworkCache.Cache.Entry
  alias AppworkCache.Response

  describe "new/2 and valid?/2" do
    test "builds expires_at from response TTL" do
      now = ~U[2026-01-01 00:00:00Z]
      response = %Response{body: %{id: "users/1"}, ttl_seconds: 60}

      entry = Entry.new(response, now)

      assert entry.response == response
      assert entry.expires_at == ~U[2026-01-01 00:01:00Z]
    end

    test "is valid before expires_at" do
      entry = %Entry{
        response: %Response{body: %{}, ttl_seconds: 10},
        expires_at: ~U[2026-01-01 00:01:00Z]
      }

      assert Entry.valid?(entry, ~U[2026-01-01 00:00:30Z])
    end

    test "is invalid at or after expires_at" do
      entry = %Entry{
        response: %Response{body: %{}, ttl_seconds: 10},
        expires_at: ~U[2026-01-01 00:01:00Z]
      }

      refute Entry.valid?(entry, ~U[2026-01-01 00:01:00Z])
      refute Entry.valid?(entry, ~U[2026-01-01 00:02:00Z])
    end
  end
end
