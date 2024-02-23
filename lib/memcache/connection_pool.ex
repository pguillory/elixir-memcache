defmodule Memcache.ConnectionPool do
  alias Memcache.Connection
  use Supervisor

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  def select_connection(pool \\ __MODULE__) do
    case Supervisor.which_children(pool) do
      [] ->
        {:error, :no_connections}

      [{_id, connection, :worker, [Connection]}] ->
        {:ok, connection}

      [_, _ | _] = children ->
        children
        |> Enum.take_random(2)
        |> Enum.map(fn {_id, connection, :worker, [Connection]} ->
          connection
        end)
        |> Enum.min_by(fn connection ->
          {:message_queue_len, message_queue_len} = Process.info(connection, :message_queue_len)
          message_queue_len
        end)
        |> case do
          connection -> {:ok, connection}
        end
    end
  end

  @impl true
  def init(opts) do
    connection_count = Keyword.get(opts, :connection_count, 8)

    children =
      Enum.map(1..connection_count, fn id ->
        Supervisor.child_spec(Connection, id: id)
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
