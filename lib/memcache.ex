defmodule Memcache do
  alias Memcache.CommandBatch
  alias Memcache.Connection
  alias Memcache.ConnectionPool

  def connect(opts \\ []) do
    Connection.start_link(opts)
  end

  def flush_all(connection_or_batch, exptime \\ 0) do
    command(connection_or_batch, {:flush_all, exptime})
  end

  def set(connection_or_batch, key, value, exptime \\ 0) do
    flags = 0
    command(connection_or_batch, {:set, key, value, flags, exptime})
  end

  def add(connection_or_batch, key, value, exptime \\ 0) do
    flags = 0
    command(connection_or_batch, {:add, key, value, flags, exptime})
  end

  def replace(connection_or_batch, key, value, exptime \\ 0) do
    flags = 0
    command(connection_or_batch, {:replace, key, value, flags, exptime})
  end

  def append(connection_or_batch, key, value) do
    flags = 0
    exptime = 0
    command(connection_or_batch, {:append, key, value, flags, exptime})
  end

  def prepend(connection_or_batch, key, value) do
    flags = 0
    exptime = 0
    command(connection_or_batch, {:prepend, key, value, flags, exptime})
  end

  def cas(connection_or_batch, key, value, cas_unique, exptime \\ 0) do
    flags = 0
    command(connection_or_batch, {:cas, key, value, cas_unique, flags, exptime})
  end

  def get(connection_or_batch, key) do
    command(connection_or_batch, {:get, key})
  end

  def gets(connection_or_batch, key) do
    command(connection_or_batch, {:gets, key})
  end

  def delete(connection_or_batch, key) do
    command(connection_or_batch, {:delete, key})
  end

  def incr(connection_or_batch, key, value) do
    command(connection_or_batch, {:incr, key, value})
  end

  def decr(connection_or_batch, key, value) do
    command(connection_or_batch, {:decr, key, value})
  end

  def touch(connection_or_batch, key, exptime \\ 0) do
    command(connection_or_batch, {:touch, key, exptime})
  end

  def gat(connection_or_batch, key, exptime \\ 0) do
    command(connection_or_batch, {:gat, key, exptime})
  end

  def gats(connection_or_batch, key, exptime \\ 0) do
    command(connection_or_batch, {:gats, key, exptime})
  end

  def meta_debug(connection_or_batch, key) do
    command(connection_or_batch, {:me, key})
  end

  def meta_get(connection_or_batch, key, flags \\ []) do
    command(connection_or_batch, {:mg, key, flags})
  end

  def meta_set(connection_or_batch, key, value, flags \\ []) do
    command(connection_or_batch, {:ms, key, value, flags})
  end

  def meta_delete(connection_or_batch, key, flags \\ []) do
    command(connection_or_batch, {:md, key, flags})
  end

  def meta_arithmetic(connection_or_batch, key, flags \\ []) do
    command(connection_or_batch, {:ma, key, flags})
  end

  def meta_noop(connection_or_batch) do
    command(connection_or_batch, {:mn})
  end

  defp command(connection, command) when is_pid(connection) do
    batch = CommandBatch.new() |> CommandBatch.add(command) |> CommandBatch.to_list()

    case Connection.execute(connection, batch) do
      [result] -> result
    end
  end

  defp command(pool, command) when is_atom(pool) do
    {:ok, connection} = ConnectionPool.select_connection(pool)
    command(connection, command)
  end

  defp command(batch, command) when is_list(batch) do
    CommandBatch.add(batch, command)
  end

  def batch do
    CommandBatch.new()
  end

  def execute(batch, connection) do
    batch = CommandBatch.to_list(batch)
    Connection.execute(connection, batch)
  end
end
