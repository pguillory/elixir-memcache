defmodule Eventually do
  defmacro eventually(condition, timeout \\ 5000) when is_integer(timeout) do
    quote do
      deadline = System.monotonic_time(:millisecond) + unquote(timeout)

      Stream.iterate(0, &(&1 + 1))
      |> Enum.reduce_while(nil, fn delay, _ ->
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
