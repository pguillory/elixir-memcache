defmodule Memcache do
  alias Memcache.Command
  alias Memcache.Connection
  alias Memcache.Router
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    children = [
      {Router, opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def flush_all(exptime \\ 0) do
    Command.flush_all(exptime) |> execute()
  end

  def set(key, value, exptime \\ 0) do
    Command.set(key, value, exptime) |> execute()
  end

  def add(key, value, exptime \\ 0) do
    Command.add(key, value, exptime) |> execute()
  end

  def replace(key, value, exptime \\ 0) do
    Command.replace(key, value, exptime) |> execute()
  end

  def append(key, value) do
    Command.append(key, value) |> execute()
  end

  def prepend(key, value) do
    Command.prepend(key, value) |> execute()
  end

  def cas(key, value, cas_unique, exptime \\ 0) do
    Command.cas(key, value, cas_unique, exptime) |> execute()
  end

  def get(key) do
    Command.get(key) |> execute()
  end

  def gets(key) do
    Command.gets(key) |> execute()
  end

  def delete(key) do
    Command.delete(key) |> execute()
  end

  def incr(key, value) do
    Command.incr(key, value) |> execute()
  end

  def decr(key, value) do
    Command.decr(key, value) |> execute()
  end

  def touch(key, exptime \\ 0) do
    Command.touch(key, exptime) |> execute()
  end

  def gat(key, exptime \\ 0) do
    Command.gat(key, exptime) |> execute()
  end

  def gats(key, exptime \\ 0) do
    Command.gats(key, exptime) |> execute()
  end

  def meta_debug(key) do
    Command.meta_debug(key) |> execute()
  end

  def meta_get(key, flags \\ []) do
    Command.meta_get(key, flags) |> execute()
  end

  def meta_set(key, value, flags \\ []) do
    Command.meta_set(key, value, flags) |> execute()
  end

  def meta_delete(key, flags \\ []) do
    Command.meta_delete(key, flags) |> execute()
  end

  def meta_arithmetic(key, flags \\ []) do
    Command.meta_arithmetic(key, flags) |> execute()
  end

  def meta_noop do
    Command.meta_noop() |> execute()
  end

  def execute(commands) do
    execute(commands, Router)
  end

  def execute(single_command, connection) when is_tuple(single_command) do
    [result] = execute([single_command], connection)
    result
  end

  def execute(commands, Router) do
    Router.execute(commands)
  end

  def execute(commands, connection) when is_pid(connection) do
    Connection.execute(connection, commands)
  end
end
