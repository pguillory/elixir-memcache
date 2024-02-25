defmodule Memcache.Server do
  alias Memcache.Server.Record
  require Record
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    server = self()
    port = Keyword.get(opts, :port, 11211)
    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, {:active, false}, {:reuseport, true}])

    spawn_link(fn ->
      accept_connections(listen_socket, server)
    end)

    tab = :ets.new(nil, [])
    {:ok, tab}
  end

  defp accept_connections(listen_socket, server) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)

    spawn(fn ->
      :gen_tcp.controlling_process(socket, self())
      handle_requests(socket, server)
    end)

    accept_connections(listen_socket, server)
  end

  defp handle_requests(socket, server) do
    case receive_request(socket) do
      {:error, :closed} ->
        :ok

      request ->
        response = GenServer.call(server, request)
        :ok = send_response(socket, response)
        handle_requests(socket, server)
    end
  end

  defp receive_request(socket) do
    case receive_line(socket) do
      {:ok, ["flush_all", exptime]} ->
        {:flush_all, exptime}

      {:ok, ["set", key, flags, exptime, size]} ->
        with {:ok, value} <- receive_value(socket, size) do
          {:set, key, value, flags, exptime}
        end

      {:ok, ["add", key, flags, exptime, size]} ->
        with {:ok, value} <- receive_value(socket, size) do
          {:add, key, value, flags, exptime}
        end

      {:ok, ["replace", key, flags, exptime, size]} ->
        with {:ok, value} <- receive_value(socket, size) do
          {:replace, key, value, flags, exptime}
        end

      {:ok, ["append", key, flags, exptime, size]} ->
        with {:ok, value} <- receive_value(socket, size) do
          {:append, key, value, flags, exptime}
        end

      {:ok, ["prepend", key, flags, exptime, size]} ->
        with {:ok, value} <- receive_value(socket, size) do
          {:prepend, key, value, flags, exptime}
        end

      {:ok, ["cas", key, flags, exptime, size, cas_unique]} ->
        with {:ok, value} <- receive_value(socket, size) do
          cas_unique = String.to_integer(cas_unique)
          {:cas, key, value, cas_unique, flags, exptime}
        end

      {:ok, ["get", key]} ->
        {:get, key}

      {:ok, ["gets", key]} ->
        {:gets, key}

      {:ok, ["delete", key]} ->
        {:delete, key}

      {:ok, ["incr", key, value]} ->
        {:incr, key, value}

      {:ok, ["decr", key, value]} ->
        {:decr, key, value}

      {:ok, ["touch", key, exptime]} ->
        {:touch, key, exptime}

      {:ok, ["gat", exptime, key]} ->
        {:gat, key, exptime}

      {:ok, ["gats", exptime, key]} ->
        {:gats, key, exptime}

      {:ok, ["me", key]} ->
        {:me, key}

      {:ok, ["mg", key | flags]} ->
        {:mg, key, flags}

      {:ok, ["ms", key, size | flags]} ->
        with {:ok, value} <- receive_value(socket, size) do
          {:ms, key, value, flags}
        end

      {:ok, ["md", key | flags]} ->
        {:md, key, flags}

      {:ok, ["ma", key | flags]} ->
        {:ma, key, flags}

      {:ok, ["mn"]} ->
        {:mn}

      {:error, error} ->
        {:error, error}
    end
  end

  def handle_call({:flush_all, _exptime}, _, tab) do
    true = :ets.delete_all_objects(tab)
    {:reply, [["OK"]], tab}
  end

  def handle_call({:set, key, value, flags, exptime}, _, tab) do
    true = :ets.insert(tab, Record.tuple(key: key, value: value, flags: flags, exptime: exptime, cas_unique: generate_cas_unique()))
    {:reply, [["STORED"]], tab}
  end

  def handle_call({:add, key, value, flags, exptime}, _, tab) do
    case :ets.lookup(tab, key) do
      [_] ->
        {:reply, [["NOT_STORED"]], tab}
      [] ->
        true = :ets.insert(tab, Record.tuple(key: key, value: value, flags: flags, exptime: exptime, cas_unique: generate_cas_unique()))
        # true = :ets.insert(tab, {key, value, flags, exptime, generate_cas_unique()})
        {:reply, [["STORED"]], tab}
    end
  end

  def handle_call({:replace, key, value, flags, exptime}, _, tab) do
    case :ets.lookup(tab, key) do
      [_] ->
        true = :ets.insert(tab, Record.tuple(key: key, value: value, flags: flags, exptime: exptime, cas_unique: generate_cas_unique()))
        # true = :ets.insert(tab, {key, value, flags, exptime, generate_cas_unique()})
        {:reply, [["STORED"]], tab}
      [] ->
        {:reply, [["NOT_STORED"]], tab}
    end
  end

  def handle_call({:append, key, delta, _flags, _exptime}, _, tab) do
    case :ets.lookup(tab, key) do
      [{^key, value, _flags, _exptime, _cas_unique}] ->
        value = value <> delta
        true = :ets.update_element(tab, key, [{2, value}])
        {:reply, [["STORED"]], tab}
      [] ->
        {:reply, [["NOT_STORED"]], tab}
    end
  end

  def handle_call({:prepend, key, delta, _flags, _exptime}, _, tab) do
    case :ets.lookup(tab, key) do
      [{^key, value, _flags, _exptime, _cas_unique}] ->
        value = delta <> value
        true = :ets.update_element(tab, key, [{2, value}])
        {:reply, [["STORED"]], tab}
      [] ->
        {:reply, [["NOT_STORED"]], tab}
    end
  end

  def handle_call({:cas, key, value, cas_unique, flags, exptime}, _, tab) do
    case :ets.lookup(tab, key) do
      [{^key, _value, _flags, _exptime, ^cas_unique}] ->
        true = :ets.insert(tab, Record.tuple(key: key, value: value, flags: flags, exptime: exptime, cas_unique: generate_cas_unique()))
        # true = :ets.insert(tab, {key, value, flags, exptime, generate_cas_unique()})
        {:reply, [["STORED"]], tab}
      [{^key, _value, _flags, _exptime, _different_cas_unique}] ->
        {:reply, [["EXISTS"]], tab}
      [] ->
        {:reply, [["NOT_FOUND"]], tab}
    end
  end
# {:cas, key, value, cas_unique, flags, exptime}

  def handle_call({:get, key}, _, tab) do
    case :ets.lookup(tab, key) do
      [{^key, value, flags, _exptime, _cas_unique}] ->
        {:reply, [["VALUE", key, flags, byte_size(value)], [value], ["END"]], tab}
      [] ->
        {:reply, [["END"]], tab}
    end
  end

  def handle_call({:gets, key}, _, tab) do
    case :ets.lookup(tab, key) do
      [{^key, value, flags, _exptime, cas_unique}] ->
        {:reply, [["VALUE", key, flags, byte_size(value), cas_unique], [value], ["END"]], tab}
      [] ->
        {:reply, [["END"]], tab}
    end
  end

  def handle_call({:delete, key}, _, tab) do
    case :ets.lookup(tab, key) do
      [_] ->
        true = :ets.delete(tab, key)
        {:reply, [["DELETED"]], tab}
      [] ->
        {:reply, [["NOT_FOUND"]], tab}
    end
  end

  def handle_call({:incr, key, delta}, _, tab) do
    case :ets.lookup(tab, key) do
      [Record.tuple(value: value)] ->
        value = Integer.to_string(String.to_integer(value) + String.to_integer(delta))
        true = :ets.update_element(tab, key, Record.element_spec(value: value))
        {:reply, [[value]], tab}
      [] ->
        {:reply, [["NOT_FOUND"]], tab}
    end
  end

  def handle_call({:decr, key, delta}, _, tab) do
    case :ets.lookup(tab, key) do
      [Record.tuple(value: value)] ->
        value = Integer.to_string(max(0, String.to_integer(value) - String.to_integer(delta)))
        true = :ets.update_element(tab, key, Record.element_spec(value: value))
        {:reply, [[value]], tab}
      [] ->
        {:reply, [["NOT_FOUND"]], tab}
    end
  end

  def handle_call({:touch, key, exptime}, _, tab) do
    case :ets.update_element(tab, key, Record.element_spec(exptime: exptime)) do
      true ->
        {:reply, [["TOUCHED"]], tab}
      false ->
        {:reply, [["NOT_FOUND"]], tab}
    end
  end

  def handle_call({:gat, key, exptime}, _, tab) do
    case :ets.lookup(tab, key) do
      [Record.tuple(value: value, flags: flags)] ->
        true = :ets.update_element(tab, key, Record.element_spec(exptime: exptime))
        {:reply, [["VALUE", key, flags, byte_size(value)], [value], ["END"]], tab}
      [] ->
        {:reply, [["END"]], tab}
    end
  end

  def handle_call({:gats, key, exptime}, _, tab) do
    case :ets.lookup(tab, key) do
      [Record.tuple(value: value, flags: flags, cas_unique: cas_unique)] ->
        true = :ets.update_element(tab, key, Record.element_spec(exptime: exptime))
        {:reply, [["VALUE", key, flags, byte_size(value), cas_unique], [value], ["END"]], tab}
      [] ->
        {:reply, [["END"]], tab}
    end
  end

  def handle_call({:me, key}, _, tab) do
    case :ets.lookup(tab, key) do
      [Record.tuple(exptime: exptime, cas_unique: cas_unique) = record] ->
        total_size = :erlang.term_to_binary(record) |> byte_size()
        {:reply, [["ME", key, "exp=#{exptime}", "la=0", "cas=#{cas_unique}", "fetch=yes", "cls=0", "size=#{total_size}"]], tab}
      [] ->
        {:reply, [["EN"]], tab}
    end
  end

  def handle_call({:mg, key, opts}, _, tab) do
    case :ets.lookup(tab, key) do
      [Record.tuple(value: value, flags: flags, exptime: exptime, cas_unique: cas_unique)] ->
        if "v" in opts do
          {:reply, [["VA", byte_size(value) | encode_flag_results(opts, key, value, flags, exptime, cas_unique)], [value]], tab}
        else
          {:reply, [["HD" | encode_flag_results(opts, key, value, flags, exptime, cas_unique)]], tab}
        end
      [] ->
        {:reply, [["EN"]], tab}
    end
  end

  def handle_call({:ms, key, value, opts}, _, tab) do
    cas_unique =
      Enum.find_value(opts, nil, fn
        "C" <> cas_unique -> String.to_integer(cas_unique)
        _ -> nil
      end)

    {flags, exptime} = decode_ms_flags(opts)

    mode =
      Enum.find_value(opts, :set, fn
        "ME" -> :add
        "MA" -> :append
        "MP" -> :prepend
        "MR" -> :replace
        "MS" -> :set
        _ -> nil
      end)

    case :ets.lookup(tab, key) do
      [Record.tuple(cas_unique: different_cas_unique)] when cas_unique != nil and cas_unique != different_cas_unique ->
        cas_unique = 0
        {:reply, [["EX" | encode_flag_results(opts, key, value, flags, exptime, cas_unique)]], tab}

      [] when cas_unique != nil ->
        cas_unique = 0
        {:reply, [["NF" | encode_flag_results(opts, key, value, flags, exptime, cas_unique)]], tab}

      [] when mode in [:append, :prepend, :replace] ->
        cas_unique = 0
        {:reply, [["NS" | encode_flag_results(opts, key, value, flags, exptime, cas_unique)]], tab}

      [_] when mode == :add ->
        cas_unique = 0
        {:reply, [["NS" | encode_flag_results(opts, key, value, flags, exptime, cas_unique)]], tab}

      [Record.tuple(value: old_value)] when mode == :append ->
        value = old_value <> value
        cas_unique = generate_cas_unique()
        true = :ets.insert(tab, Record.tuple(key: key, value: value, flags: flags, exptime: exptime, cas_unique: cas_unique))
        {:reply, [["HD" | encode_flag_results(opts, key, value, flags, exptime, cas_unique)]], tab}

      [Record.tuple(value: old_value)] when mode == :prepend ->
        value = value <> old_value
        cas_unique = generate_cas_unique()
        true = :ets.insert(tab, Record.tuple(key: key, value: value, flags: flags, exptime: exptime, cas_unique: cas_unique))
        {:reply, [["HD" | encode_flag_results(opts, key, value, flags, exptime, cas_unique)]], tab}

      _ ->
        cas_unique = generate_cas_unique()
        true = :ets.insert(tab, Record.tuple(key: key, value: value, flags: flags, exptime: exptime, cas_unique: cas_unique))
        {:reply, [["HD" | encode_flag_results(opts, key, value, flags, exptime, cas_unique)]], tab}
    end
  end

  def handle_call({:md, key, opts}, _, tab) do
    cas_unique =
      Enum.find_value(opts, nil, fn
        "C" <> cas_unique -> String.to_integer(cas_unique)
        _ -> nil
      end)

    case :ets.lookup(tab, key) do
      [Record.tuple(cas_unique: different_cas_unique)] when cas_unique != nil and cas_unique != different_cas_unique ->
        {:reply, [["EX" | encode_flag_results(opts, key, nil, nil, nil, nil)]], tab}

      [_] ->
        true = :ets.delete(tab, key)
        {:reply, [["HD" | encode_flag_results(opts, key, nil, nil, nil, nil)]], tab}

      [] ->
        {:reply, [["NF"]], tab}
    end
  end

  def handle_call({:ma, key, opts}, _, tab) do
    cas_unique =
      Enum.find_value(opts, nil, fn
        "C" <> token -> String.to_integer(token)
        _ -> nil
      end)

    initial_ttl =
      Enum.find_value(opts, nil, fn
        "N" <> token -> String.to_integer(token)
        _ -> nil
      end)

    initial_value =
      Enum.find_value(opts, 0, fn
        "J" <> token -> token
        _ -> nil
      end)

    delta =
      Enum.find_value(opts, 1, fn
        "D" <> token -> token
        _ -> nil
      end)

    # update_ttl =
    #   Enum.find_value(opts, nil, fn
    #     "T" <> token -> String.to_integer(token)
    #     _ -> nil
    #   end)

    mode =
      Enum.find_value(opts, :increment, fn
        "MI" -> :increment
        "MD" -> :decrement
        _ -> nil
      end)

    case :ets.lookup(tab, key) do
      [Record.tuple(cas_unique: different_cas_unique)] when cas_unique != nil and cas_unique != different_cas_unique ->
        {:reply, [["EX" | encode_flag_results(opts, key, nil, nil, nil, nil)]], tab}

      [Record.tuple(value: value, exptime: exptime)] ->
        value =
          case mode do
            :increment -> Integer.to_string(String.to_integer(value) + String.to_integer(delta))
            :decrement -> Integer.to_string(max(0, String.to_integer(value) - String.to_integer(delta)))
          end

        cas_unique = generate_cas_unique()
        true = :ets.update_element(tab, key, Record.element_spec(value: value, cas_unique: cas_unique))

        if "v" in opts do
          {:reply, [["VA", byte_size(value) | encode_flag_results(opts, key, value, nil, exptime, cas_unique)], [value]], tab}
        else
          {:reply, [["HD" | encode_flag_results(opts, key, value, nil, exptime, cas_unique)]], tab}
        end

      [] when initial_ttl != nil ->
        value = initial_value
        flags = 0
        exptime = initial_ttl
        cas_unique = generate_cas_unique()
        true = :ets.insert(tab, Record.tuple(key: key, value: value, flags: flags, exptime: exptime, cas_unique: cas_unique))

        if "v" in opts do
          {:reply, [["VA", byte_size(value) | encode_flag_results(opts, key, value, nil, exptime, cas_unique)], [value]], tab}
        else
          {:reply, [["HD" | encode_flag_results(opts, key, value, nil, exptime, cas_unique)]], tab}
        end

      [] ->
        {:reply, [["NF"]], tab}
    end

    # {:reply, [["NF"]], tab}
  end

  def handle_call({:mn}, _, tab) do
    {:reply, [["MN"]], tab}
  end

  defp decode_ms_flags(opts) do
    flags = 0
    ttl = 0
    decode_ms_flags(opts, flags, ttl)
  end

  defp decode_ms_flags(["F" <> flags | opts], _flags, ttl) do
    flags = String.to_integer(flags)
    decode_ms_flags(opts, flags, ttl)
  end

  defp decode_ms_flags(["T" <> ttl | opts], flags, _ttl) do
    ttl = String.to_integer(ttl)
    decode_ms_flags(opts, flags, ttl)
  end

  defp decode_ms_flags([_ | opts], flags, ttl) do
    decode_ms_flags(opts, flags, ttl)
  end

  defp decode_ms_flags([], flags, ttl) do
    {flags, ttl}
  end


  defp encode_flag_results(opts, key, value, flags, exptime, cas_unique) do
    Enum.flat_map(opts, fn
      "c" when cas_unique != nil -> ["c#{cas_unique}"]
      "f" when flags != nil -> ["f#{flags}"]
      "k" when key != nil -> ["k#{key}"]
      # "l" -> ["l#{last_access}"]
      "O" <> token -> ["O" <> token]
      "s" when value != nil -> ["s#{byte_size(value)}"]
      "t" when exptime != nil -> ["t#{exptime}"]
      _ -> []
    end)
  end

  def generate_cas_unique do
    System.unique_integer([:positive])
  end

  defp receive_line(socket) do
    case :inet.setopts(socket, [{:packet, :line}]) do
      :ok ->
        case :gen_tcp.recv(socket, 0, :infinity) do
          {:ok, "ERROR\r\n"} ->
            {:error, :invalid_command}

          {:ok, "CLIENT_ERROR " <> error} ->
            {:error, {:client_error, String.trim_trailing(error, "\r\n")}}

          {:ok, "SERVER_ERROR " <> error} ->
            {:error, {:server_error, String.trim_trailing(error, "\r\n")}}

          {:ok, packet} ->
            {:ok, String.split(packet)}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp receive_value(socket, size) do
    size = String.to_integer(size)

    case receive_bytes(socket, size + 2) do
      {:ok, <<value::binary-size(size), "\r\n">>} ->
        {:ok, value}

      {:error, error} ->
        {:error, error}
    end
  end

  defp receive_bytes(socket, size) do
    case :inet.setopts(socket, [{:packet, :raw}]) do
      :ok ->
        case :gen_tcp.recv(socket, size, :infinity) do
          {:ok, packet} ->
            {:ok, packet}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_response(socket, lines) do
    packet =
      Enum.map(lines, fn line ->
        [Enum.map_join(line, " ", &to_string/1) | "\r\n"]
      end)

    :gen_tcp.send(socket, packet)
  end
end
