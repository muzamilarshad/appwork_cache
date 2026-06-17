defmodule AppworkCache.Cache.LRUTest do
  use ExUnit.Case, async: true

  alias AppworkCache.Cache.LRU

  describe "touch/2" do
    test "appends a new hash to the back" do
      assert LRU.touch([], :a) == [:a]
      assert LRU.touch([:a], :b) == [:a, :b]
    end

    test "moves an existing hash to the back" do
      assert LRU.touch([:a, :b, :c], :a) == [:b, :c, :a]
    end
  end

  describe "insert/3" do
    test "does not evict when at capacity" do
      assert {:ok, [:a, :b], nil} = LRU.insert([:a], :b, 2)
    end

    test "evicts the LRU entry when over capacity" do
      assert {:ok, [:b, :c], :a} = LRU.insert([:a, :b], :c, 2)
    end

    test "promotes on insert of an existing hash before evicting" do
      assert {:ok, [:c, :a], :b} = LRU.insert([:a, :b, :c], :a, 2)
    end
  end

end
