defmodule MemcacheTest do
  import Memcache
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
    :ok = flush_all()
  end

  test "set" do
    assert set("a", "1") == :ok
    assert get("a") == {:ok, "1"}
  end

  test "add" do
    assert add("a", "1") == :ok
    assert get("a") == {:ok, "1"}
  end

  test "add not_stored" do
    assert set("a", "1") == :ok
    assert add("a", "1") == {:error, :not_stored}
    assert get("a") == {:ok, "1"}
  end

  test "replace" do
    assert set("a", "1") == :ok
    assert replace("a", "2") == :ok
    assert get("a") == {:ok, "2"}
  end

  test "replace not_stored" do
    assert replace("a", "1") == {:error, :not_stored}
    assert get("a") == {:error, :not_found}
  end

  test "append" do
    assert set("a", "1") == :ok
    assert append("a", "2") == :ok
    assert get("a") == {:ok, "12"}
  end

  test "append not_stored" do
    assert append("a", "1") == {:error, :not_stored}
    assert get("a") == {:error, :not_found}
  end

  test "prepend" do
    assert set("a", "1") == :ok
    assert prepend("a", "2") == :ok
    assert get("a") == {:ok, "21"}
  end

  test "prepend not_stored" do
    assert append("a", "1") == {:error, :not_stored}
    assert get("a") == {:error, :not_found}
  end

  test "cas not_found" do
    assert cas("a", "1", 1) == {:error, :not_found}
    assert get("a") == {:error, :not_found}
  end

  test "cas" do
    assert set("a", "1") == :ok
    assert {:ok, "1", cas_unique} = gets("a")
    assert cas("a", "2", cas_unique) == :ok
    assert get("a") == {:ok, "2"}
  end

  test "cas exists" do
    assert set("a", "1") == :ok
    assert {:ok, "1", cas_unique} = gets("a")
    cas_unique2 = different_cas_unique(cas_unique)
    assert cas("a", "2", cas_unique2) == {:error, :exists}
    assert get("a") == {:ok, "1"}
  end

  test "delete" do
    assert set("a", "1") == :ok
    assert get("a") == {:ok, "1"}
    assert delete("a") == :ok
    assert get("a") == {:error, :not_found}
  end

  test "incr not_found" do
    assert incr("a", 1) == {:error, :not_found}
    assert get("a") == {:error, :not_found}
  end

  test "incr" do
    assert set("a", "1") == :ok
    assert incr("a", 2) == {:ok, 3}
    assert get("a") == {:ok, "3"}
  end

  test "decr not_found" do
    assert decr("a", 1) == {:error, :not_found}
    assert get("a") == {:error, :not_found}
  end

  test "decr" do
    assert set("a", "1") == :ok
    assert decr("a", 1) == {:ok, 0}
    assert get("a") == {:ok, "0"}
  end

  test "decr underflow" do
    assert set("a", "1") == :ok
    assert decr("a", 2) == {:ok, 0}
    assert get("a") == {:ok, "0"}
  end

  test "touch" do
    assert set("a", "1") == :ok
    assert touch("a") == :ok
    assert get("a") == {:ok, "1"}
  end

  test "gat" do
    assert set("a", "1") == :ok
    assert gat("a") == {:ok, "1"}
  end

  test "gats" do
    assert set("a", "1") == :ok
    assert {:ok, "1", cas_unique} = gets("a")
    assert gats("a") == {:ok, "1", cas_unique}
  end

  test "meta_debug" do
    assert set("a", "1") == :ok
    assert {:ok, map} = meta_debug("a")
    assert %{size: _, exp: _, fetch: _, cas: _, la: _, cls: _} = map
  end

  test "meta_debug not_found" do
    assert meta_debug("a") == {:error, :not_found}
  end

  test "meta_get return_cas" do
    assert set("a", "1") == :ok
    assert {:ok, "1", cas_unique} = gets("a")
    assert meta_get("a", return_cas: true) == {:ok, %{cas: cas_unique}}
  end

  test "meta_get return_flags" do
    assert set("a", "1") == :ok
    assert meta_get("a", return_flags: true) == {:ok, %{flags: 0}}
  end

  test "meta_get return_hit" do
    assert set("a", "1") == :ok
    assert meta_get("a", return_hit: true) == {:ok, %{hit: false}}
    assert meta_get("a", return_hit: true) == {:ok, %{hit: true}}
  end

  test "meta_get return_key" do
    assert set("a", "1") == :ok
    assert meta_get("a", return_key: true) == {:ok, %{key: "a"}}
  end

  test "meta_get return_last_access)" do
    assert set("a", "1") == :ok
    # potentially flakey
    # assert meta_get("a", return_last_access: true) == {:ok, %{l: 0}}
  end

  test "meta_get opaque_token" do
    assert set("a", "1") == :ok
    assert meta_get("a", opaque_token: "foo") == {:ok, %{opaque_token: "foo"}}
  end

  test "meta_get return_value" do
    assert set("a", "1") == :ok
    assert meta_get("a", return_value: true) == {:ok, %{value: "1"}}
  end

  test "meta_get not_found" do
    assert meta_get("a") == {:error, :not_found}
  end

  test "meta_set" do
    assert meta_set("a", "1") == {:ok, %{}}
  end

  describe "meta_set" do
    test "return_cas" do
      assert {:ok, %{cas: cas_unique}} = meta_set("a", "1", return_cas: true)
      assert gets("a") == {:ok, "1", cas_unique}
    end

    test "compare_cas" do
      assert {:ok, %{cas: cas_unique}} = meta_set("a", "1", return_cas: true)
      assert meta_set("a", "2", compare_cas: cas_unique) == {:ok, %{}}
    end

    test "compare_cas, exists" do
      assert {:ok, %{cas: cas_unique}} = meta_set("a", "1", return_cas: true)
      cas_unique2 = different_cas_unique(cas_unique)
      assert meta_set("a", "2", compare_cas: cas_unique2) == {:error, :exists}
    end

    test "set_flags" do
      assert meta_set("a", "1", set_flags: 123) == {:ok, %{}}
      assert meta_get("a", return_flags: true) == {:ok, %{flags: 123}}
    end

    # test "invalidate" do
    #   assert meta_set("a", "1", invalidate: true) == {:ok, %{}}
    # end

    test "return_key" do
      assert meta_set("a", "1", return_key: true) == {:ok, %{key: "a"}}
    end

    test "opaque_token" do
      assert meta_set("a", "1", opaque_token: "foo") == {:ok, %{opaque_token: "foo"}}
    end

    test "return_size" do
      assert meta_set("a", "1", return_size: true) == {:ok, %{size: 1}}
    end

    test "set_ttl" do
      assert meta_set("a", "1", set_ttl: 0) == {:ok, %{}}
    end

    test "add mode" do
      assert meta_set("a", "1", mode: :add) == {:ok, %{}}
    end

    test "add mode not_stored" do
      :ok = set("a", "1")
      assert meta_set("a", "1", mode: :add) == {:error, :not_stored}
    end

    test "replace mode" do
      :ok = set("a", "1")
      assert meta_set("a", "2", mode: :replace) == {:ok, %{}}
      assert get("a") == {:ok, "2"}
    end

    test "replace mode not_stored" do
      assert meta_set("a", "1", mode: :replace) == {:error, :not_stored}
    end

    test "append mode" do
      :ok = set("a", "1")
      assert meta_set("a", "2", mode: :append) == {:ok, %{}}
      assert get("a") == {:ok, "12"}
    end

    test "append mode not_stored" do
      assert meta_set("a", "1", mode: :append) == {:error, :not_stored}
    end

    test "prepend mode" do
      :ok = set("a", "1")
      assert meta_set("a", "2", mode: :prepend) == {:ok, %{}}
      assert get("a") == {:ok, "21"}
    end

    test "prepend mode not_stored" do
      assert meta_set("a", "1", mode: :prepend) == {:error, :not_stored}
    end

    test "set mode" do
      assert meta_set("a", "1", mode: :set) == {:ok, %{}}
      assert get("a") == {:ok, "1"}
    end
  end

  test "meta_delete" do
    :ok = set("a", "1")
    assert meta_delete("a") == {:ok, %{}}
  end

  test "meta_delete not_stored" do
    assert meta_delete("a") == {:error, :not_found}
  end

  test "meta_delete exists" do
    {:ok, %{cas: cas_unique}} = meta_set("a", "1", return_cas: true)
    cas_unique2 = different_cas_unique(cas_unique)
    assert meta_delete("a", compare_cas: cas_unique2) == {:error, :exists}
    assert meta_delete("a", compare_cas: cas_unique) == {:ok, %{}}
  end

  test "meta_delete opaque_token" do
    :ok = set("a", "1")
    assert meta_delete("a", opaque_token: "foo") == {:ok, %{opaque_token: "foo"}}
  end

  test "meta_arithmetic touch_on_miss initial_value" do
    assert meta_arithmetic("a",
             touch_on_miss: 0,
             initial_value: 5,
             delta: 7,
             return_value: true
           ) == {:ok, %{value: "5"}}

    assert meta_arithmetic("a",
             touch_on_miss: 0,
             initial_value: 5,
             delta: 7,
             return_value: true
           ) == {:ok, %{value: "12"}}
  end

  test "meta_noop" do
    assert meta_noop() == :ok
  end

  defp different_cas_unique(cas_unique) do
    rem(cas_unique + 1, 65_536)
  end
end
