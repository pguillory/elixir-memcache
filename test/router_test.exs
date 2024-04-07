defmodule Memcache.RouterTest do
  import Eventually
  import Memcache.Router
  use ExUnit.Case

  test "set" do
    {:ok, _server} = start_supervised({Memcache.Server, port: 11212})
    {:ok, _router} = start_supervised({Memcache.Router, hosts: ["127.0.0.1:11212"]})
    commands = Memcache.set([], "key", "value")
    results = execute(commands)
    assert results == [:ok]
  end

  test "reconnecting" do
    log_output =
      ExUnit.CaptureIO.capture_io(fn ->
        {:ok, _server} = start_supervised({Memcache.Server, port: 11212})
        {:ok, _router} = start_supervised({Memcache.Router, hosts: ["127.0.0.1:11212"]})
        [{"127.0.0.1:11212", connection}] = :ets.tab2list(Memcache.Router)
        Process.exit(connection, :kill)
        eventually :ets.tab2list(Memcache.Router) != [{"127.0.0.1:11212", connection}]
        [{"127.0.0.1:11212", _connection2}] = :ets.tab2list(Memcache.Router)
      end)

    assert log_output == "Reconnecting memcache 127.0.0.1:11212 because :killed\n"
  end
end
