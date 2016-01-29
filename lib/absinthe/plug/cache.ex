defmodule Absinthe.Plug.Cache do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def put(k, v) do
    GenServer.call(__MODULE__, {:put, k, v})
  end

  def get(k) do
    case :ets.lookup(__MODULE__, k) do
      [{_, v}] -> v
      _ ->
        v = k.schema
        :ok = put(k, v)
        v
    end
  end

  def init([]) do
    ets = :ets.new(__MODULE__, [:named_table, read_concurrency: true])
    {:ok, ets}
  end

  def handle_call({:put, k, v}, _from, ets) do
    :ets.insert(ets, {k, v})
    {:reply, :ok, ets}
  end
end
