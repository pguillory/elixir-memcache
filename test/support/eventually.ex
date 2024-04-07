defmodule Eventually do
  defmacro eventually(condition, timeout \\ 5000) when is_integer(timeout) do
    quote do
      timeout = unquote(timeout)
      start_time = System.monotonic_time(:millisecond)
      deadline = start_time + timeout

      Stream.iterate(0, &(&1 + 1))
      |> Enum.reduce_while(nil, fn delay, nil ->
        if unquote(condition) do
          {:halt, nil}
        else
          remaining_time = deadline - System.monotonic_time(:millisecond)

          if remaining_time > 0 do
            Process.sleep(min(delay, remaining_time))
            {:cont, nil}
          else
            assert unquote(condition)
            {:halt, nil}
          end
        end
      end)
    end
  end
end
