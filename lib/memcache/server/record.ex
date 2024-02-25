defmodule Memcache.Server.Record do
  defmacro tuple(opts \\ []) do
    underscore = quote do
      _
    end

    {key, opts} = Keyword.pop_first(opts, :key, underscore)
    {value, opts} = Keyword.pop_first(opts, :value, underscore)
    {flags, opts} = Keyword.pop_first(opts, :flags, underscore)
    {exptime, opts} = Keyword.pop_first(opts, :exptime, underscore)
    {cas_unique, opts} = Keyword.pop_first(opts, :cas_unique, underscore)
    # {last_access, opts} = Keyword.pop_first(opts, :last_access, underscore)
    [] = opts

    quote do
      {unquote(key), unquote(value), unquote(flags), unquote(exptime), unquote(cas_unique)}
    end
  end

  def key_to_offset(key) do
    case key do
      :key -> 1
      :value -> 2
      :flags -> 3
      :exptime -> 4
      :cas_unique -> 5
      # :last_access -> 6
    end
  end

  def element_spec(opts \\ []) do
    Enum.map(opts, fn
      {key, value} -> {key_to_offset(key), value}
    end)
  end

  # def match_spec(opts \\ []) do
  # end
end
