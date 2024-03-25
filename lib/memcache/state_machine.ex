defmodule Memcache.StateMachine do
  alias Memcache.CommandBatch
  alias Memcache.Connection

  def single_command(machines, command) do
    add(machines, :single_command, [command], fn
      :single_command, [result] ->
        {result, []}
    end)
  end

  # TODO: thundering herd mitigation
  def read_through(machines, key, opts \\ [], func) do
    ttl = Keyword.get(opts, :ttl, 0)

    add(machines, :get, Memcache.get([], key), fn
      :get, [{:ok, value}] ->
        # Cache hit.
        {{:ok, value}, []}

      :get, [error: :not_found] ->
        # Cache miss.
        value = func.()
        {{:set, value}, Memcache.set([], key, value, ttl)}

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

  def read_through_term(machines, key, opts \\ [], func) do
    ttl = Keyword.get(opts, :ttl, 0)

    add(machines, :get, Memcache.get([], key), fn
      :get, [{:ok, value}] ->
        # Cache hit.
        {{:ok, :erlang.binary_to_term(value)}, []}

      :get, [error: :not_found] ->
        # Cache miss.
        value = func.()
        {{:set, value}, Memcache.set([], key, :erlang.term_to_binary(value), ttl)}

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

  def read_modify_write(machines, key, opts \\ [], func) do
    ttl = Keyword.get(opts, :ttl, 0)

    add(machines, :gets, Memcache.gets([], key), fn
      :gets, [{:ok, old_value, cas_unique}] ->
        new_value = func.({:ok, old_value})
        {{:cas, new_value}, Memcache.cas([], key, new_value, cas_unique, ttl)}

      :gets, [error: :not_found] ->
        new_value = func.({:error, :not_found})
        {{:add, new_value}, Memcache.add([], key, new_value, ttl)}

      {:cas, new_value}, [:ok] ->
        {{:ok, new_value}, []}

      {:cas, _new_value}, [error: :exists] ->
        # Race condition, the key changed after we read it. Try again.
        {:gets, Memcache.gets([], key)}

      {:cas, _new_value}, [error: :not_found] ->
        # Race condition, the key expired after we read it. Try again.
        new_value = func.({:error, :not_found})
        {:add, Memcache.add([], key, new_value, ttl)}

      {:add, new_value}, [:ok] ->
        {{:ok, new_value}, []}

      {:add, _new_value}, [error: :not_stored] ->
        # Race condition, the key was created after we read it. Try again.
        {:gets, Memcache.gets([], key)}

      _, {:error, error} ->
        {{:error, error}, []}
    end)
  end

  def with_lock(machines, key, opts \\ [], func) do
    ttl = Keyword.get(opts, :ttl, 0)

    add(machines, :add, Memcache.add([], key, "locked", ttl), fn
      :add, [:ok] ->
        value = func.()
        {{:delete, value}, Memcache.delete([], key)}

      :add, [error: :not_stored] ->
        # TODO: retry
        {{:error, :busy}, []}

      {:delete, value}, [:ok] ->
        {{:ok, value}, []}

      {:delete, value}, [error: _error] ->
        {{:ok, value}, []}
    end)
  end

  def new do
    []
  end

  def add(connection, state, batch, func) when is_pid(connection) do
    new()
    |> add(state, batch, func)
    |> run(connection)
    |> case do
      [result] -> result
    end
  end

  def add(machines, state, batch, func) when is_list(machines) do
    machine = {state, batch, func}
    [machine | machines]
  end

  def run(machines, connection) when is_pid(connection) do
    Enum.reverse(machines)
    |> run2(connection)
  end

  defp run2(machines, connection) do
    machines
    |> Enum.map(fn {_state, batch, _func} ->
      CommandBatch.to_list(batch)
    end)
    |> flattened(fn
      [_ | _] = flattened_batch ->
        Connection.execute(connection, flattened_batch)

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
    |> run2(connection)
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
