defmodule AppworkCache.RequestTest do
  use ExUnit.Case, async: true

  alias AppworkCache.Request

  describe "hash/1" do
    test "is stable for the same id" do
      req = %Request{id: "users/42"}

      assert Request.hash(req) == Request.hash(req)
    end

    test "differs for different ids" do
      a = %Request{id: "users/42"}
      b = %Request{id: "users/43"}

      assert Request.hash(a) != Request.hash(b)
    end
  end
end
