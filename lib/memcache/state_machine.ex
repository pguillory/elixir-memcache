defmodule Memcache.StateMachine do
  import Memcache.Command

  def single_command(command) do
    machine(:single_command, [command], fn
      :single_command, [result] ->
        {result, []}
    end)
  end

  # TODO: thundering herd mitigation
  def read_through(key, opts \\ [], func) do
    ttl = Keyword.get(opts, :ttl, 0)

    machine(:get, [get(key)], fn
      :get, [{:ok, value}] ->
        # Cache hit.
        {{:ok, value}, []}

      :get, [error: :not_found] ->
        # Cache miss.
        value = func.()
        {{:set, value}, [set(key, value, ttl)]}

      :get, [error: _error] ->
        # Some problem trying to get cached value. Memcache unavailable? Don't bother trying to set.
        value = func.()
        {{:ok, value}, []}

      {:set, value}, [:ok] ->
        {{:ok, value}, []}

      {:set, value}, [error: _error] ->
        # Failed to set value after a cache miss. Don't bother trying again. Just return the value we have.
        {{:ok, value}, []}
    end)
  end

  def read_through_term(key, opts \\ [], func) do
    ttl = Keyword.get(opts, :ttl, 0)

    machine(:get, [get(key)], fn
      :get, [{:ok, value}] ->
        # Cache hit.
        {{:ok, :erlang.binary_to_term(value)}, []}

      :get, [error: :not_found] ->
        # Cache miss.
        value = func.()
        {{:set, value}, [set(key, :erlang.term_to_binary(value), ttl)]}

      :get, [error: _error] ->
        # Some problem trying to get cached value. Memcache unavailable? Don't bother trying to set.
        value = func.()
        {{:ok, value}, []}

      {:set, value}, [:ok] ->
        {{:ok, value}, []}

      {:set, value}, [error: _error] ->
        # Failed to set value after a cache miss. Don't bother trying again. Just return the value we have.
        {{:ok, value}, []}
    end)
  end

  def read_modify_write(key, opts \\ [], func) do
    ttl = Keyword.get(opts, :ttl, 0)

    machine(:gets, [gets(key)], fn
      :gets, [{:ok, old_value, cas_unique}] ->
        new_value = func.({:ok, old_value})
        {{:cas, new_value}, [cas(key, new_value, cas_unique, ttl)]}

      :gets, [error: :not_found] ->
        new_value = func.({:error, :not_found})
        {{:add, new_value}, [add(key, new_value, ttl)]}

      {:cas, new_value}, [:ok] ->
        {{:ok, new_value}, []}

      {:cas, _new_value}, [error: :exists] ->
        # Race condition, the key changed after we read it. Try again.
        {:gets, [gets(key)]}

      {:cas, _new_value}, [error: :not_found] ->
        # Race condition, the key expired after we read it. Try again.
        new_value = func.({:error, :not_found})
        {:add, [add(key, new_value, ttl)]}

      {:add, new_value}, [:ok] ->
        {{:ok, new_value}, []}

      {:add, _new_value}, [error: :not_stored] ->
        # Race condition, the key was created after we read it. Try again.
        {:gets, [gets(key)]}

      _, {:error, error} ->
        {{:error, error}, []}
    end)
  end

  def with_lock(key, opts \\ [], func) do
    ttl = Keyword.get(opts, :ttl, 0)

    machine(:add, [add(key, "locked", ttl)], fn
      :add, [:ok] ->
        value = func.()
        {{:delete, value}, [delete(key)]}

      :add, [error: :not_stored] ->
        # TODO: retry
        {{:error, :busy}, []}

      {:delete, value}, [:ok] ->
        {{:ok, value}, []}

      {:delete, value}, [error: _error] ->
        {{:ok, value}, []}
    end)
  end

  def machine(initial_state, commands, func) when is_list(commands) and is_function(func, 2) do
    {initial_state, commands, func}
  end

  def run(machines) do
    run(machines, Memcache.Router)
  end

  def run(machine, connection) when is_tuple(machine) do
    [result] = run([machine], connection)
    result
  end

  def run(machines, connection) when is_list(machines) do
    machines
    |> Enum.map(fn {_state, commands, _func} ->
      commands
    end)
    |> flattened(fn
      [_ | _] = flattened_commands ->
        Memcache.execute(flattened_commands, connection)

      [] ->
        throw(:all_machines_stopped)
    end)
    |> Enum.zip_with(machines, fn
      [_ | _] = result, {state, [_ | _], func} = _running_machine ->
        {new_state, new_batch} = func.(state, result)
        {new_state, new_batch, func}

      [], {_, [], _} = stopped_machine ->
        stopped_machine
    end)
    |> run(connection)
  catch
    :all_machines_stopped ->
      # All machines are stopped.
      Enum.map(machines, fn {state, [], _func} ->
        state
      end)
  end

  def flattened(lists, func) do
    unflatten(func.(flatten(lists)), lists)
  end

  def flatten(list) do
    flatten(list, [])
  end

  defp flatten([], bb) do
    bb
  end

  defp flatten([a | aa], bb) do
    flatten(a, flatten(aa, bb))
  end

  defp flatten(a, bb) do
    [a | bb]
  end

  def unflatten(aa, bb) do
    {cc, []} = unflatten2(aa, bb)
    cc
  end

  defp unflatten2(aa, []) do
    {[], aa}
  end

  defp unflatten2(aa, [b | bb]) when is_list(b) do
    {c, aa} = unflatten2(aa, b)
    {cc, aa} = unflatten2(aa, bb)
    {[c | cc], aa}
  end

  defp unflatten2([a | aa], [b | bb]) when not is_list(b) do
    {cc, aa} = unflatten2(aa, bb)
    {[a | cc], aa}
  end
end
