defmodule Memcache.Connection do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def start(opts \\ []) do
    GenServer.start(__MODULE__, opts, opts)
  end

  def execute(connection, batch) when is_list(batch) do
    batch
    |> Enum.chunk_every(20)
    |> Enum.map(fn batch ->
      GenServer.call(connection, {:execute, batch})
    end)
    |> Enum.concat()
  end

  def init(opts) do
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 11211)
    {:ok, socket} = :gen_tcp.connect(String.to_charlist(host), port, [:binary, {:active, false}])

    state = %{
      socket: socket
    }

    {:ok, state}
  end

  def handle_call({:execute, batch}, _, state) do
    batch
    |> Enum.map(fn command ->
      {send_command(command, state), command}
    end)
    |> Enum.map(fn
      {:ok, command} ->
        receive_response(command, state)

      {{:error, _} = error, _command} ->
        error
    end)
    |> case do
      responses -> {:reply, responses, state}
    end
  end

  defp send_command(command, state) do
    case command do
      {:flush_all, exptime} ->
        send_flush_all(exptime, state)

      {:set, key, value, flags, exptime} ->
        send_set(key, value, flags, exptime, state)

      {:add, key, value, flags, exptime} ->
        send_add(key, value, flags, exptime, state)

      {:replace, key, value, flags, exptime} ->
        send_replace(key, value, flags, exptime, state)

      {:append, key, value, flags, exptime} ->
        send_append(key, value, flags, exptime, state)

      {:prepend, key, value, flags, exptime} ->
        send_prepend(key, value, flags, exptime, state)

      {:cas, key, value, cas_unique, flags, exptime} ->
        send_cas(key, value, cas_unique, flags, exptime, state)

      {:get, key} ->
        send_get(key, state)

      {:gets, key} ->
        send_gets(key, state)

      {:delete, key} ->
        send_delete(key, state)

      {:incr, key, value} ->
        send_incr(key, value, state)

      {:decr, key, value} ->
        send_decr(key, value, state)

      {:touch, key, exptime} ->
        send_touch(key, exptime, state)

      {:gat, key, exptime} ->
        send_gat(key, exptime, state)

      {:gats, key, exptime} ->
        send_gats(key, exptime, state)

      {:me, key} ->
        send_me(key, state)

      {:mg, key, flags} ->
        send_mg(key, flags, state)

      {:ms, key, value, flags} ->
        send_ms(key, value, flags, state)

      {:md, key, flags} ->
        send_md(key, flags, state)

      {:ma, key, flags} ->
        send_ma(key, flags, state)

      {:mn} ->
        send_mn(state)
    end
  end

  defp receive_response(command, state) do
    case command do
      {:flush_all, _exptime} ->
        receive_flush_all(state)

      {:set, _key, _value, _flags, _exptime} ->
        receive_set(state)

      {:add, _key, _value, _flags, _exptime} ->
        receive_add(state)

      {:replace, _key, _value, _flags, _exptime} ->
        receive_replace(state)

      {:append, _key, _value, _flags, _exptime} ->
        receive_append(state)

      {:prepend, _key, _value, _flags, _exptime} ->
        receive_prepend(state)

      {:cas, _key, _value, _cas_unique, _flags, _exptime} ->
        receive_cas(state)

      {:get, key} ->
        receive_get(key, state)

      {:gets, key} ->
        receive_gets(key, state)

      {:delete, _key} ->
        receive_delete(state)

      {:incr, _key, _value} ->
        receive_incr(state)

      {:decr, _key, _value} ->
        receive_decr(state)

      {:touch, _key, _exptime} ->
        receive_touch(state)

      {:gat, key, _exptime} ->
        receive_gat(key, state)

      {:gats, key, _exptime} ->
        receive_gats(key, state)

      {:me, key} ->
        receive_me(key, state)

      {:mg, _key, _flags} ->
        receive_mg(state)

      {:ms, _key, _value, _flags} ->
        receive_ms(state)

      {:md, _key, _flags} ->
        receive_md(state)

      {:ma, _key, _flags} ->
        receive_ma(state)

      {:mn} ->
        receive_mn(state)
    end
  end

  defp send_flush_all(exptime, state) do
    send_lines(state, [["flush_all", exptime]])
  end

  defp receive_flush_all(state) do
    case receive_line(state) do
      {:ok, ["OK"]} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_set(key, value, flags, exptime, state) do
    send_lines(state, [["set", key, flags, exptime, IO.iodata_length(value)], [value]])
  end

  defp receive_set(state) do
    case receive_line(state) do
      {:ok, ["STORED"]} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_add(key, value, flags, exptime, state) do
    send_lines(state, [["add", key, flags, exptime, IO.iodata_length(value)], [value]])
  end

  defp receive_add(state) do
    case receive_line(state) do
      {:ok, ["STORED"]} ->
        :ok

      {:ok, ["NOT_STORED"]} ->
        {:error, :not_stored}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_replace(key, value, flags, exptime, state) do
    send_lines(state, [["replace", key, flags, exptime, IO.iodata_length(value)], [value]])
  end

  defp receive_replace(state) do
    case receive_line(state) do
      {:ok, ["STORED"]} ->
        :ok

      {:ok, ["NOT_STORED"]} ->
        {:error, :not_stored}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_append(key, value, flags, exptime, state) do
    send_lines(state, [["append", key, flags, exptime, IO.iodata_length(value)], [value]])
  end

  defp receive_append(state) do
    case receive_line(state) do
      {:ok, ["STORED"]} ->
        :ok

      {:ok, ["NOT_STORED"]} ->
        {:error, :not_stored}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_prepend(key, value, flags, exptime, state) do
    send_lines(state, [["prepend", key, flags, exptime, IO.iodata_length(value)], [value]])
  end

  defp receive_prepend(state) do
    case receive_line(state) do
      {:ok, ["STORED"]} ->
        :ok

      {:ok, ["NOT_STORED"]} ->
        {:error, :not_stored}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_cas(key, value, cas_unique, flags, exptime, state) do
    send_lines(state, [["cas", key, flags, exptime, IO.iodata_length(value), cas_unique], [value]])
  end

  defp receive_cas(state) do
    case receive_line(state) do
      {:ok, ["STORED"]} ->
        :ok

      {:ok, ["NOT_FOUND"]} ->
        {:error, :not_found}

      {:ok, ["EXISTS"]} ->
        {:error, :exists}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_get(key, state) do
    send_lines(state, [["get", key]])
  end

  defp receive_get(key, state) do
    case receive_line(state) do
      {:ok, ["VALUE", ^key, _flags, size]} ->
        size = String.to_integer(size)

        case receive_bytes(state, size + 2) do
          {:ok, <<value::binary-size(size), "\r\n">>} ->
            case receive_line(state) do
              {:ok, ["END"]} ->
                {:ok, value}

              {:error, error} ->
                {:error, error}
            end

          {:error, error} ->
            {:error, error}
        end

      {:ok, ["END"]} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_gets(key, state) do
    send_lines(state, [["gets", key]])
  end

  defp receive_gets(key, state) do
    case receive_line(state) do
      {:ok, ["VALUE", ^key, _flags, size, cas_unique]} ->
        size = String.to_integer(size)
        cas_unique = String.to_integer(cas_unique)

        case receive_bytes(state, size + 2) do
          {:ok, <<value::binary-size(size), "\r\n">>} ->
            case receive_line(state) do
              {:ok, ["END"]} ->
                {:ok, value, cas_unique}

              {:error, error} ->
                {:error, error}
            end

          {:error, error} ->
            {:error, error}
        end

      {:ok, ["END"]} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_delete(key, state) do
    send_lines(state, [["delete", key]])
  end

  defp receive_delete(state) do
    case receive_line(state) do
      {:ok, ["DELETED"]} ->
        :ok

      {:ok, ["NOT_FOUND"]} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_incr(key, value, state) do
    send_lines(state, [["incr", key, value]])
  end

  defp receive_incr(state) do
    case receive_line(state) do
      {:ok, ["NOT_FOUND"]} ->
        {:error, :not_found}

      {:ok, [value]} ->
        {:ok, String.to_integer(value)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_decr(key, value, state) do
    send_lines(state, [["decr", key, value]])
  end

  defp receive_decr(state) do
    case receive_line(state) do
      {:ok, ["NOT_FOUND"]} ->
        {:error, :not_found}

      {:ok, [value]} ->
        {:ok, String.to_integer(value)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_touch(key, exptime, state) do
    send_lines(state, [["touch", key, exptime]])
  end

  defp receive_touch(state) do
    case receive_line(state) do
      {:ok, ["TOUCHED"]} ->
        :ok

      {:ok, ["NOT_FOUND"]} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_gat(key, exptime, state) do
    send_lines(state, [["gat", exptime, key]])
  end

  defp receive_gat(key, state) do
    receive_get(key, state)
  end

  defp send_gats(key, exptime, state) do
    send_lines(state, [["gats", exptime, key]])
  end

  defp receive_gats(key, state) do
    receive_gets(key, state)
  end

  defp send_me(key, state) do
    send_lines(state, [["me", key]])
  end

  defp receive_me(key, state) do
    case receive_line(state) do
      {:ok, ["ME", ^key | kv_pairs]} ->
        {:ok, decode_meta_debug_kv_pairs(kv_pairs)}

      {:ok, ["EN"]} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp decode_meta_debug_kv_pairs(kv_pairs) do
    Enum.reduce(kv_pairs, %{}, fn kv_pair, map ->
      case String.split(kv_pair, "=") do
        [key, value] ->
          Map.put(map, String.to_atom(key), value)

        _ ->
          map
      end
    end)
  end

  defp send_mg(key, flags, state) do
    send_lines(state, [["mg", key | encode_flags(flags)]])
  end

  defp receive_mg(state) do
    case receive_line(state) do
      {:ok, ["VA", size | flag_results]} ->
        size = String.to_integer(size)

        case receive_bytes(state, size + 2) do
          {:ok, <<value::binary-size(size), "\r\n">>} ->
            {:ok, decode_flag_results(flag_results) |> Map.put(:value, value)}

          {:error, error} ->
            {:error, error}
        end

      {:ok, ["HD" | flag_results]} ->
        {:ok, decode_flag_results(flag_results)}

      {:ok, ["EN"]} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_ms(key, value, flags, state) do
    send_lines(state, [["ms", key, IO.iodata_length(value) | encode_flags(flags)], [value]])
  end

  defp receive_ms(state) do
    case receive_line(state) do
      {:ok, ["HD" | flag_results]} ->
        {:ok, decode_flag_results(flag_results)}

      {:ok, ["NS"]} ->
        {:error, :not_stored}

      {:ok, ["EX"]} ->
        {:error, :exists}

      {:ok, ["NF"]} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_md(key, flags, state) do
    send_lines(state, [["md", key | encode_flags(flags)]])
  end

  defp receive_md(state) do
    case receive_line(state) do
      {:ok, ["HD" | flag_results]} ->
        {:ok, decode_flag_results(flag_results)}

      {:ok, ["NF"]} ->
        {:error, :not_found}

      {:ok, ["EX"]} ->
        {:error, :exists}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_ma(key, flags, state) do
    send_lines(state, [["ma", key | encode_flags(flags)]])
  end

  defp receive_ma(state) do
    case receive_line(state) do
      {:ok, ["VA", size | flag_results]} ->
        size = String.to_integer(size)

        case receive_bytes(state, size + 2) do
          {:ok, <<value::binary-size(size), "\r\n">>} ->
            {:ok, decode_flag_results(flag_results) |> Map.put(:value, value)}

          {:error, error} ->
            {:error, error}
        end

      {:ok, ["HD" | flag_results]} ->
        {:ok, decode_flag_results(flag_results)}

      {:ok, ["NF"]} ->
        {:error, :not_found}

      {:ok, ["NS"]} ->
        {:error, :not_stored}

      {:ok, ["EX"]} ->
        {:error, :exists}

      {:error, error} ->
        {:error, error}
    end
  end

  defp send_mn(state) do
    send_lines(state, [["mn"]])
  end

  defp receive_mn(state) do
    case receive_line(state) do
      {:ok, ["MN"]} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  defp encode_flags(flags) do
    Enum.map(flags, fn
      {:return_cas, true} -> "c"
      {:return_flags, true} -> "f"
      {:return_hit, true} -> "h"
      {:return_key, true} -> "k"
      {:return_last_access, true} -> "k"
      {:opaque_token, token} -> "O#{token}"
      {:return_size, true} -> "s"
      {:return_ttl, true} -> "t"
      {:bump_lru, false} -> "u"
      {:return_value, true} -> "v"
      {:touch_on_miss, ttl} when is_integer(ttl) -> "N#{ttl}"
      {:win_for_recache, ttl} when is_integer(ttl) -> "R#{ttl}"
      {:set_ttl, ttl} when is_integer(ttl) -> "T#{ttl}"
      {:set_flags, flags} when is_integer(flags) -> "F#{flags}"
      {:compare_cas, cas} when is_integer(cas) -> "C#{cas}"
      {:invalidate, true} -> "I"
      {:mode, :add} -> "ME"
      {:mode, :append} -> "MA"
      {:mode, :prepend} -> "MP"
      {:mode, :replace} -> "MR"
      {:mode, :set} -> "MS"
      {:mode, :increment} -> "MI"
      {:mode, :decrement} -> "MD"
      {:initial_value, value} when is_integer(value) -> "J#{value}"
      {:delta, value} when is_integer(value) -> "D#{value}"
    end)

    # |> IO.inspect(label: "encoded_flags")
  end

  defp decode_flag_results(flags) do
    Map.new(flags, fn
      "c" <> value -> {:cas, String.to_integer(value)}
      "f" <> value -> {:flags, String.to_integer(value)}
      "h0" -> {:hit, false}
      "h1" -> {:hit, true}
      "k" <> value -> {:key, value}
      "l" <> value -> {:last_access, String.to_integer(value)}
      "O" <> value -> {:opaque_token, value}
      "s" <> value -> {:size, String.to_integer(value)}
      "t-1" -> {:ttl, :infinity}
      "t" <> value -> {:ttl, String.to_integer(value)}
      "W" -> {:won, true}
      "X" -> {:stale, true}
      "Z" -> {:winning, true}
    end)
  end

  defp send_lines(state, lines) do
    packet =
      Enum.map(lines, fn line ->
        [Enum.map_join(line, " ", &to_string/1) | "\r\n"]
      end)

    :gen_tcp.send(state.socket, packet)
  end

  defp receive_line(state) do
    case :inet.setopts(state.socket, [{:packet, :line}]) do
      :ok ->
        case :gen_tcp.recv(state.socket, 0, :infinity) do
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

  defp receive_bytes(state, size) do
    case :inet.setopts(state.socket, [{:packet, :raw}]) do
      :ok ->
        case :gen_tcp.recv(state.socket, size, :infinity) do
          {:ok, packet} ->
            {:ok, packet}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end
end
