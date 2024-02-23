defmodule MemcacheTest do
  import Memcache
  use ExUnit.Case

  setup do
    {:ok, memcache} = connect()
    :ok = flush_all(memcache)
    %{memcache: memcache}
  end

  test "set", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert get(memcache, "a") == {:ok, "1"}
  end

  test "add", %{memcache: memcache} do
    assert add(memcache, "a", "1") == :ok
    assert get(memcache, "a") == {:ok, "1"}
  end

  test "add not_stored", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert add(memcache, "a", "1") == {:error, :not_stored}
    assert get(memcache, "a") == {:ok, "1"}
  end

  test "replace", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert replace(memcache, "a", "2") == :ok
    assert get(memcache, "a") == {:ok, "2"}
  end

  test "replace not_stored", %{memcache: memcache} do
    assert replace(memcache, "a", "1") == {:error, :not_stored}
    assert get(memcache, "a") == {:error, :not_found}
  end

  test "append", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert append(memcache, "a", "2") == :ok
    assert get(memcache, "a") == {:ok, "12"}
  end

  test "append not_stored", %{memcache: memcache} do
    assert append(memcache, "a", "1") == {:error, :not_stored}
    assert get(memcache, "a") == {:error, :not_found}
  end

  test "cas not_found", %{memcache: memcache} do
    assert cas(memcache, "a", "1", 1) == {:error, :not_found}
    assert get(memcache, "a") == {:error, :not_found}
  end

  test "cas", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert {:ok, "1", cas_unique} = gets(memcache, "a")
    assert cas(memcache, "a", "2", cas_unique) == :ok
    assert get(memcache, "a") == {:ok, "2"}
  end

  test "cas exists", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert {:ok, "1", cas_unique} = gets(memcache, "a")
    cas_unique2 = different_cas_unique(cas_unique)
    assert cas(memcache, "a", "2", cas_unique2) == {:error, :exists}
    assert get(memcache, "a") == {:ok, "1"}
  end

  test "delete", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert get(memcache, "a") == {:ok, "1"}
    assert delete(memcache, "a") == :ok
    assert get(memcache, "a") == {:error, :not_found}
  end

  test "incr not_found", %{memcache: memcache} do
    assert incr(memcache, "a", 1) == {:error, :not_found}
    assert get(memcache, "a") == {:error, :not_found}
  end

  test "incr", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert incr(memcache, "a", 2) == {:ok, 3}
    assert get(memcache, "a") == {:ok, "3"}
  end

  test "decr not_found", %{memcache: memcache} do
    assert decr(memcache, "a", 1) == {:error, :not_found}
    assert get(memcache, "a") == {:error, :not_found}
  end

  test "decr", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert decr(memcache, "a", 1) == {:ok, 0}
    assert get(memcache, "a") == {:ok, "0"}
  end

  test "decr underflow", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert decr(memcache, "a", 2) == {:ok, 0}
    assert get(memcache, "a") == {:ok, "0"}
  end

  test "touch", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert touch(memcache, "a") == :ok
    assert get(memcache, "a") == {:ok, "1"}
  end

  test "gat", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert gat(memcache, "a") == {:ok, "1"}
  end

  test "gats", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert {:ok, "1", cas_unique} = gets(memcache, "a")
    assert gats(memcache, "a") == {:ok, "1", cas_unique}
  end

  test "meta_debug", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert {:ok, map} = meta_debug(memcache, "a")
    assert %{size: _, exp: _, fetch: _, cas: _, la: _, cls: _} = map
  end

  test "meta_debug not_found", %{memcache: memcache} do
    assert meta_debug(memcache, "a") == {:error, :not_found}
  end

  test "meta_get return_cas", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert {:ok, "1", cas_unique} = gets(memcache, "a")
    assert meta_get(memcache, "a", return_cas: true) == {:ok, %{cas: cas_unique}}
  end

  test "meta_get return_flags", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert meta_get(memcache, "a", return_flags: true) == {:ok, %{flags: 0}}
  end

  test "meta_get return_hit", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert meta_get(memcache, "a", return_hit: true) == {:ok, %{hit: false}}
    assert meta_get(memcache, "a", return_hit: true) == {:ok, %{hit: true}}
  end

  test "meta_get return_key", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert meta_get(memcache, "a", return_key: true) == {:ok, %{key: "a"}}
  end

  test "meta_get return_last_access)", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    # potentially flakey
    # assert meta_get(memcache, "a", return_last_access: true) == {:ok, %{l: 0}}
  end

  test "meta_get opaque_token", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert meta_get(memcache, "a", opaque_token: "foo") == {:ok, %{opaque_token: "foo"}}
  end

  test "meta_get return_value", %{memcache: memcache} do
    assert set(memcache, "a", "1") == :ok
    assert meta_get(memcache, "a", return_value: true) == {:ok, %{value: "1"}}
  end

  test "meta_get not_found", %{memcache: memcache} do
    assert meta_get(memcache, "a") == {:error, :not_found}
  end

  test "meta_set", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1") == {:ok, %{}}
  end

  test "meta_set return_cas", %{memcache: memcache} do
    assert {:ok, %{cas: cas_unique}} = meta_set(memcache, "a", "1", return_cas: true)
    assert gets(memcache, "a") == {:ok, "1", cas_unique}
  end

  test "meta_set compare_cas", %{memcache: memcache} do
    assert {:ok, %{cas: cas_unique}} = meta_set(memcache, "a", "1", return_cas: true)
    assert meta_set(memcache, "a", "2", compare_cas: cas_unique) == {:ok, %{}}
  end

  test "meta_set compare_cas, exists", %{memcache: memcache} do
    assert {:ok, %{cas: cas_unique}} = meta_set(memcache, "a", "1", return_cas: true)
    cas_unique2 = different_cas_unique(cas_unique)
    assert meta_set(memcache, "a", "2", compare_cas: cas_unique2) == {:error, :exists}
  end

  test "meta_set set_flags", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", set_flags: 123) == {:ok, %{}}
    assert meta_get(memcache, "a", return_flags: true) == {:ok, %{flags: 123}}
  end

  # test "meta_set invalidate", %{memcache: memcache} do
  #   assert meta_set(memcache, "a", "1", invalidate: true) == {:ok, %{}}
  # end

  test "meta_set return_key", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", return_key: true) == {:ok, %{key: "a"}}
  end

  test "meta_set opaque_token", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", opaque_token: "foo") == {:ok, %{opaque_token: "foo"}}
  end

  test "meta_set return_size", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", return_size: true) == {:ok, %{size: 1}}
  end

  test "meta_set set_ttl", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", set_ttl: 0) == {:ok, %{}}
  end

  test "meta_set add mode", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", mode: :add) == {:ok, %{}}
  end

  test "meta_set add mode not_stored", %{memcache: memcache} do
    :ok = set(memcache, "a", "1")
    assert meta_set(memcache, "a", "1", mode: :add) == {:error, :not_stored}
  end

  test "meta_set replace mode", %{memcache: memcache} do
    :ok = set(memcache, "a", "1")
    assert meta_set(memcache, "a", "2", mode: :replace) == {:ok, %{}}
    assert get(memcache, "a") == {:ok, "2"}
  end

  test "meta_set replace mode not_stored", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", mode: :replace) == {:error, :not_stored}
  end

  test "meta_set append mode", %{memcache: memcache} do
    :ok = set(memcache, "a", "1")
    assert meta_set(memcache, "a", "2", mode: :append) == {:ok, %{}}
    assert get(memcache, "a") == {:ok, "12"}
  end

  test "meta_set append mode not_stored", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", mode: :append) == {:error, :not_stored}
  end

  test "meta_set prepend mode", %{memcache: memcache} do
    :ok = set(memcache, "a", "1")
    assert meta_set(memcache, "a", "2", mode: :prepend) == {:ok, %{}}
    assert get(memcache, "a") == {:ok, "21"}
  end

  test "meta_set prepend mode not_stored", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", mode: :prepend) == {:error, :not_stored}
  end

  test "meta_set set mode", %{memcache: memcache} do
    assert meta_set(memcache, "a", "1", mode: :set) == {:ok, %{}}
    assert get(memcache, "a") == {:ok, "1"}
  end

  test "meta_delete", %{memcache: memcache} do
    :ok = set(memcache, "a", "1")
    assert meta_delete(memcache, "a") == {:ok, %{}}
  end

  test "meta_delete not_stored", %{memcache: memcache} do
    assert meta_delete(memcache, "a") == {:error, :not_found}
  end

  test "meta_delete exists", %{memcache: memcache} do
    {:ok, %{cas: cas_unique}} = meta_set(memcache, "a", "1", return_cas: true)
    cas_unique2 = different_cas_unique(cas_unique)
    assert meta_delete(memcache, "a", compare_cas: cas_unique2) == {:error, :exists}
    assert meta_delete(memcache, "a", compare_cas: cas_unique) == {:ok, %{}}
  end

  test "meta_delete opaque_token", %{memcache: memcache} do
    :ok = set(memcache, "a", "1")
    assert meta_delete(memcache, "a", opaque_token: "foo") == {:ok, %{opaque_token: "foo"}}
  end

  test "meta_arithmetic touch_on_miss initial_value", %{memcache: memcache} do
    assert meta_arithmetic(memcache, "a",
             touch_on_miss: 0,
             initial_value: 5,
             delta: 7,
             return_value: true
           ) == {:ok, %{value: "5"}}

    assert meta_arithmetic(memcache, "a",
             touch_on_miss: 0,
             initial_value: 5,
             delta: 7,
             return_value: true
           ) == {:ok, %{value: "12"}}
  end

  test "meta_noop", %{memcache: memcache} do
    assert meta_noop(memcache) == :ok
  end

  defp different_cas_unique(cas_unique) do
    rem(cas_unique + 1, 65_536)
  end
end
