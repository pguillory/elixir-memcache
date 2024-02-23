defmodule Memcache.CommandBatch do
  def new do
    []
  end

  def add(batch, command) when is_list(batch) do
    [command | batch]
  end

  def to_list(batch) do
    Enum.reverse(batch)
  end
end
