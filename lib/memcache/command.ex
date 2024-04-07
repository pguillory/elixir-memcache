defmodule Memcache.Command do
  def flush_all(exptime \\ 0) do
    {:flush_all, exptime}
  end

  def set(key, value, exptime \\ 0) do
    flags = 0
    {:set, key, value, flags, exptime}
  end

  def add(key, value, exptime \\ 0) do
    flags = 0
    {:add, key, value, flags, exptime}
  end

  def replace(key, value, exptime \\ 0) do
    flags = 0
    {:replace, key, value, flags, exptime}
  end

  def append(key, value) do
    flags = 0
    exptime = 0
    {:append, key, value, flags, exptime}
  end

  def prepend(key, value) do
    flags = 0
    exptime = 0
    {:prepend, key, value, flags, exptime}
  end

  def cas(key, value, cas_unique, exptime \\ 0) do
    flags = 0
    {:cas, key, value, cas_unique, flags, exptime}
  end

  def get(key) do
    {:get, key}
  end

  def gets(key) do
    {:gets, key}
  end

  def delete(key) do
    {:delete, key}
  end

  def incr(key, value) do
    {:incr, key, value}
  end

  def decr(key, value) do
    {:decr, key, value}
  end

  def touch(key, exptime \\ 0) do
    {:touch, key, exptime}
  end

  def gat(key, exptime \\ 0) do
    {:gat, key, exptime}
  end

  def gats(key, exptime \\ 0) do
    {:gats, key, exptime}
  end

  def meta_debug(key) do
    {:me, key}
  end

  def meta_get(key, flags \\ []) do
    {:mg, key, flags}
  end

  def meta_set(key, value, flags \\ []) do
    {:ms, key, value, flags}
  end

  def meta_delete(key, flags \\ []) do
    {:md, key, flags}
  end

  def meta_arithmetic(key, flags \\ []) do
    {:ma, key, flags}
  end

  def meta_noop do
    {:mn}
  end
end
