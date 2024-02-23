defmodule Memcache.ConnectionPoolTest do
  alias Memcache.ConnectionPool
  import Memcache.ConnectionPool
  use ExUnit.Case

  setup do
    {:ok, _} = start_supervised({ConnectionPool, name: :test_pool})
    :ok
  end

  test "select_connection" do
    assert {:ok, connection} = select_connection(:test_pool)
    assert is_pid(connection)
    assert Memcache.meta_noop(connection) == :ok
  end

  test "using a pool in place of connection" do
    assert Memcache.meta_noop(:test_pool) == :ok
  end
end
