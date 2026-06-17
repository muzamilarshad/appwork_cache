defmodule AppworkCache.Cache.LRU do
  @moduledoc """
  Pure LRU queue helpers for distinct cache keys.

  The queue lists hashes from least recently used (front) to most recently
  used (back). `touch/2` promotes a key to the back; `insert/3` touches a
  key and evicts the front when capacity is exceeded.
  """

  @type hash :: term()
  @type queue :: [hash()]

  @doc """
  Promotes `hash` to most recently used (back of queue).
  """
  @spec touch(queue(), hash()) :: queue()
  def touch(queue, hash) do
    queue
    |> List.delete(hash)
    |> Kernel.++([hash])
  end

  @doc """
  Promotes `hash` and evicts the LRU entry when `length(queue) > cap`.

  Returns the updated queue and the evicted hash, if any.
  """
  @spec insert(queue(), hash(), pos_integer()) :: {:ok, queue(), hash() | nil}
  def insert(queue, hash, cap) do
    queue = touch(queue, hash)

    if length(queue) > cap do
      {rest, evicted} = evict_lru(queue)
      {:ok, rest, evicted}
    else
      {:ok, queue, nil}
    end
  end

  @doc """
  Removes and returns the least recently used hash (front of queue).
  """
  @spec evict_lru(queue()) :: {queue(), hash() | nil}
  def evict_lru([]), do: {[], nil}

  def evict_lru([lru | rest]), do: {rest, lru}
end
