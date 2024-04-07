defmodule Memcache.Router do
  alias Memcache.Connection
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    hosts = Keyword.fetch!(opts, :hosts)
    :ets.new(__MODULE__, [:named_table])

    Enum.each(hosts, fn host_and_port ->
      :ok = start_connection(host_and_port)
    end)

    state = nil
    {:ok, state}
  end

  def start_connection(host_and_port) do
    [host, port] = String.split(host_and_port, ":")
    port = String.to_integer(port)
    {:ok, connection} = Connection.start(host: host, port: port)
    Process.monitor(connection)
    :ets.insert(__MODULE__, {host_and_port, connection})
    :ok
  end

  def handle_info({:DOWN, _ref, _, connection, reason}, state) do
    [host_and_port] = :ets.select(__MODULE__, [{{:"$1", connection}, [], [:"$1"]}])
    IO.puts("Reconnecting memcache #{host_and_port} because #{inspect(reason)}")
    :ok = start_connection(host_and_port)
    {:noreply, state}
  end

  def execute(commands) do
    hosts_and_connections = :ets.tab2list(__MODULE__)
    execute(commands, hosts_and_connections)
  end

  defp execute(commands, []) do
    Enum.map(commands, fn _ ->
      {:error, :no_connections}
    end)
  end

  defp execute(commands, [{_host, connection}]) do
    GenServer.call(connection, {:execute, commands})
  end

  defp execute(commands, hosts_and_connections) do
    host_to_connection = Map.new(hosts_and_connections)
    {all_hosts, _connections} = Enum.unzip(hosts_and_connections)

    hosts_per_command =
      Enum.map(commands, fn command ->
        case elem(command, 0) do
          :mn ->
            []

          :flush_all ->
            all_hosts

          _ ->
            key = elem(command, 1)
            host = Enum.min_by(all_hosts, &:erlang.phash2({key, &1}))
            [host]
        end
      end)

    results_per_host =
      Enum.zip_reduce(commands, hosts_per_command, %{}, fn command, hosts, map ->
        Enum.reduce(hosts, map, fn host, map ->
          Map.update(map, host, [command], &[command | &1])
        end)
      end)
      |> Enum.map(fn {host, commands} ->
        connection = Map.fetch!(host_to_connection, host)
        commands = Enum.reverse(commands)
        ref = Process.monitor(connection)
        send(connection, {:"$gen_call", {self(), ref}, {:execute, commands}})
        deadline = System.monotonic_time(:millisecond) + 5000
        {host, commands, deadline, ref}
      end)
      |> Map.new(fn {host, commands, deadline, ref} ->
        timeout = max(0, deadline - System.monotonic_time(:millisecond))

        receive do
          {^ref, results} ->
            Process.demonitor(ref, [:flush])
            {host, results}

          {:DOWN, ^ref, _process_atom, _connection_pid, _reason} ->
            results = Enum.map(commands, fn _ -> {:error, :disconnected} end)
            {host, results}
        after
          timeout ->
            :erlang.exit({:timeout, {__MODULE__, :execute, [commands]}})
        end
      end)

    {results, _remaining_results_per_host} =
      Enum.map_reduce(hosts_per_command, results_per_host, fn hosts, results_per_host ->
        case hosts do
          [] ->
            result = :ok
            {result, results_per_host}

          [host] ->
            Map.get_and_update!(results_per_host, host, fn
              [result | results] -> {result, results}
            end)

          [_, _ | _] ->
            {[result | _duplicate_results], results_per_host} =
              Enum.map_reduce(hosts, results_per_host, fn host, results_per_host ->
                Map.get_and_update!(results_per_host, host, fn
                  [result | results] -> {result, results}
                end)
              end)

            # Enum.each(duplicate_results, fn ^result -> nil end)
            {result, results_per_host}
        end
      end)

    # Enum.each(remaining_results_per_host, fn {_host, []} -> nil end)
    results
  end
end
