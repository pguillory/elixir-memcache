# Memcache

Memcache client for Elixir with support for pipelining.

    {:ok, memcache} = Memcache.connect()
    :ok = Memcache.set(memcache, "key", "value")
    {:ok, "value"} = Memcache.get(memcache, "key")

## Pipelined Execution

All commands (get, set, etc.) can be executed both individually or as part of
a batch of commands. In other words, these are equivalent in terms of
behavior:

    :ok = Memcache.set(memcache, "key1", "value1")
    :ok = Memcache.set(memcache, "key2", "value2")

    [:ok, :ok] =
      Memcache.batch()
      |> Memcache.set("key1", "value1")
      |> Memcache.set("key2", "value2")
      |> Memcache.execute(memcache)

However, note that they are *not* equivalent in terms of performance. The
batched commands are executed using pipelining: the requests for all commands
are sent, *then* the responses for all commands are received. This allows for
a large degree of concurrency. Typically we can execute a batch of commands
in only slightly more time than a single command.

    # Sequential
    |                |
    | ---request1--> |
    | <--response1-- |
    |                |
    | ---request2--> |
    | <--response2-- |
    |                |

    # Pipelined
    |                |
    | ---request1--> |
    | ---request2--> |
    |                |
    | <--response1-- |
    | <--response2-- |
    |                |

## State Machines

Memcache is often accessed in certain patterns. For example, in
the "read-through cache" pattern, we read a cached value, or if not found,
generate the value and write it back. Or in the "read-modify-write" pattern,
we read a value, modify it, and write it back, taking advantage of the cas
(compare-and-set) command to avoid losing data from race conditions.

When we have many instances of such patterns, doing them linearly may
introduce too much latency. Doing them in parallel with multiple processes
(perhaps using Task.async_stream) may introduce too much CPU overhead.

It would be nice to take advantage of pipelined execution. Run the first
Memcache command for all instances as a batch, do any CPU work, then run the
second command for all instances, and so on until they're all done. This gets
us most of the concurrency of parallel execution, but without the CPU
overhead.

The Memcache.StateMachine module provides this capability. An access pattern
is encoded as a state machine, then many instances of these state machines
can be run simultaneously. It includes some examples (described below) as well
as the ability to encode custom state machines.

    Memcache.StateMachine.new()
    |> Memcache.StateMachine.read_through(cache_key, fn ->
      MyDatabase.expensive_call()
    end)
    |> Memcache.StateMachine.execute(memcache)

### Read-Through Cache

        ┌─────┐       ┌────────┐
    ──► │ get │ ────► │ return │
        └─────┘       └────────┘
           │   ┌─────┐    ▲
           └─► │ set │ ───┘
               └─────┘

The original and probably most common way of using Memcache. We first try to
look up a cached value with `get`. If found, we're done. Otherwise generate
the value (perhaps with an expensive database call or computation), then
write the value back with a `set`.

    Memcache.StateMachine.read_through(memcache, cache_key, fn ->
      MyDatabase.expensive_call()
    end)

### Read-Modify-Write

                     ┌─────┐
           ┌───────► │ cas │ ────────┐
           │         └─────┘         ▼
        ┌──────┐ ◄──────┘        ┌────────┐
    ──► │ gets │                 │ return │
        └──────┘ ◄──────┐        └────────┘
           │         ┌─────┐         ▲
           └───────► │ add │ ────────┘
                     └─────┘

In this case we're using Memcache as a (semi-)persistent datastore. We read a
value, modify it, and write it back. The key is to use `cas` and `add`
operations to ensure no data is lost to race conditions. If two processes
simultaneously do a read-modify-write, the modification of one could be lost.
Whichever `cas` goes second will detect that the modification from the first
and return an error, which indicates we should start over and get the value
again.

    Memcache.StateMachine.read_modify_write(memcache, cache_key, fn
      {:error, :not_found} -> "initial value"
      {:ok, old_value} -> old_value <> "new value"
    end)

### Locking

        ┌─────┐     ┌────────┐     ┌────────┐
    ──► │ add │ ──► │ delete │ ──► │ return │
        └─────┘     └────────┘     └────────┘
          ▲ │
          └─┘

Sometimes you need to ensure that only one process is doing something at a
time. Write a key in Memcache to get a lock, then do the thing, then delete
the key to remove the lock. Using an `add` command ensures that you only get
the lock if no one else has it.

    Memcache.StateMachine.with_lock(memcache, cache_key, fn ->
      function_that_only_one_process_should_call_at_a_time()
    end)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `memcache` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:memcache, "~> 0.1.0"}
  ]
end
```
