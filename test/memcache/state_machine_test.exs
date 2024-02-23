defmodule Memcache.StateMachineTest do
  import Memcache.StateMachine
  use ExUnit.Case

  setup do
    {:ok, memcache} = Memcache.connect()
    :ok = Memcache.flush_all(memcache)
    %{memcache: memcache}
  end

  test "running state machines", %{memcache: memcache} do
    assert new()
           |> add(:mn, Memcache.meta_noop([]), fn :mn, [:ok] -> {:result1, []} end)
           |> add(:mn, Memcache.meta_noop([]), fn :mn, [:ok] -> {:result2, []} end)
           |> add(:mn, Memcache.meta_noop([]), fn :mn, [:ok] -> {:result3, []} end)
           |> run(memcache) == [
             :result1,
             :result2,
             :result3
           ]
  end

  test "read_through", %{memcache: memcache} do
    assert Memcache.get(memcache, "a") == {:error, :not_found}
    assert read_through(memcache, "a", fn -> "1" end) == {:ok, "1"}
    assert Memcache.get(memcache, "a") == {:ok, "1"}
  end

  test "read_modify_write", %{memcache: memcache} do
    func = fn
      {:error, :not_found} -> "1"
      {:ok, value} -> value <> "2"
    end

    assert Memcache.get(memcache, "a") == {:error, :not_found}
    assert read_modify_write(memcache, "a", func) == {:ok, "1"}
    assert Memcache.get(memcache, "a") == {:ok, "1"}
    assert read_modify_write(memcache, "a", func) == {:ok, "12"}
    assert Memcache.get(memcache, "a") == {:ok, "12"}
  end

  test "with_lock", %{memcache: memcache} do
    assert Memcache.get(memcache, "a") == {:error, :not_found}
    assert with_lock(memcache, "a", fn -> :success end) == {:ok, :success}
    assert Memcache.get(memcache, "a") == {:error, :not_found}
  end

  test "with_lock busy", %{memcache: memcache} do
    :ok = Memcache.set(memcache, "a", "locked")
    assert with_lock(memcache, "a", fn -> :success end) == {:error, :busy}
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
