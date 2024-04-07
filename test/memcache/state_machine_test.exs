defmodule Memcache.StateMachineTest do
  alias Memcache.Command
  import Memcache.StateMachine
  use ExUnit.Case

  def client_port do
    case System.fetch_env("MEMCACHE_PORT") do
      {:ok, port} ->
        String.to_integer(port)

      :error ->
        {:ok, _server} = start_supervised({Memcache.Server, port: 11212})
        11212
    end
  end

  setup_all do
    {:ok, _} = start_supervised({Memcache, hosts: ["localhost:#{client_port()}"]})
    :ok
  end

  setup do
    :ok = Memcache.flush_all()
  end

  test "running state machines" do
    assert [
             machine(:mn1, [Command.meta_noop()], fn :mn1, [:ok] -> {:result1, []} end),
             machine(:mn2, [Command.meta_noop()], fn :mn2, [:ok] -> {:result2, []} end),
             machine(:mn3, [Command.meta_noop()], fn :mn3, [:ok] -> {:result3, []} end)
           ]
           |> run() == [
             :result1,
             :result2,
             :result3
           ]
  end

  test "read_through" do
    assert Memcache.get("a") == {:error, :not_found}
    assert read_through("a", fn -> "1" end) |> run() == {:ok, "1"}
    assert Memcache.get("a") == {:ok, "1"}
  end

  test "read_through_term" do
    assert Memcache.get("a") == {:error, :not_found}
    assert read_through_term("a", fn -> 123 end) |> run() == {:ok, 123}
    assert Memcache.get("a") !== {:error, :not_found}
    assert read_through_term("a", fn -> 123 end) |> run() == {:ok, 123}
  end

  test "read_modify_write" do
    func = fn
      {:error, :not_found} -> "1"
      {:ok, value} -> value <> "2"
    end

    assert Memcache.get("a") == {:error, :not_found}
    assert read_modify_write("a", func) |> run() == {:ok, "1"}
    assert Memcache.get("a") == {:ok, "1"}
    assert read_modify_write("a", func) |> run() == {:ok, "12"}
    assert Memcache.get("a") == {:ok, "12"}
  end

  test "with_lock" do
    assert Memcache.get("a") == {:error, :not_found}
    assert with_lock("a", fn -> :success end) |> run() == {:ok, :success}
    assert Memcache.get("a") == {:error, :not_found}
  end

  test "with_lock busy" do
    :ok = Memcache.set("a", "locked")
    assert with_lock("a", fn -> :success end) |> run() == {:error, :busy}
  end

  test "flatten" do
    assert flatten([[]]) == []

    assert flatten([]) == []
    assert flatten([1]) == [1]
    assert flatten([[1]]) == [1]
    assert flatten([1, 2]) == [1, 2]
    assert flatten([[1], 2]) == [1, 2]
    assert flatten([1, [2]]) == [1, 2]
    assert flatten([[1], [2]]) == [1, 2]
    assert flatten([[[1]], [2]]) == [1, 2]
    assert flatten([[1], [[2]]]) == [1, 2]
    assert flatten([[[1], [2]]]) == [1, 2]
    assert flatten([[[1]], [[2]]]) == [1, 2]
    assert flatten([1, 2, 3]) == [1, 2, 3]
    assert flatten([[1], 2, 3]) == [1, 2, 3]
    assert flatten([1, [2], 3]) == [1, 2, 3]
    assert flatten([1, 2, [3]]) == [1, 2, 3]
    assert flatten([[1, 2], 3]) == [1, 2, 3]
    assert flatten([1, [2, 3]]) == [1, 2, 3]
    assert flatten([[1, 2, 3]]) == [1, 2, 3]
    assert flatten([[1], [2, 3]]) == [1, 2, 3]
    assert flatten([[1, 2], [3]]) == [1, 2, 3]
  end

  test "unflatten" do
    assert unflatten([], []) == []
    assert unflatten([], [[]]) == [[]]
    assert unflatten([], [[], []]) == [[], []]
    assert unflatten([], [[[]]]) == [[[]]]
    assert unflatten([], [[[], []]]) == [[[], []]]
    assert unflatten([], [[[]], [[]]]) == [[[]], [[]]]

    assert unflatten([1], [0]) == [1]
    assert unflatten([1], [[0]]) == [[1]]
    assert unflatten([1], [[[0]]]) == [[[1]]]

    assert unflatten([1, 2], [0, 0]) == [1, 2]
    assert unflatten([1, 2], [[0], 0]) == [[1], 2]
    assert unflatten([1, 2], [0, [0]]) == [1, [2]]
    assert unflatten([1, 2], [[0], [0]]) == [[1], [2]]
    assert unflatten([1, 2], [[0, 0]]) == [[1, 2]]
    assert unflatten([1, 2], [[[0], 0]]) == [[[1], 2]]
    assert unflatten([1, 2], [[0, [0]]]) == [[1, [2]]]
    assert unflatten([1, 2], [[[0], [0]]]) == [[[1], [2]]]
  end
end
