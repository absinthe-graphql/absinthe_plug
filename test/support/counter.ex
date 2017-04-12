defmodule Counter do
  use GenServer

  def start_link(n, opts \\ []) do
    GenServer.start_link(__MODULE__, n, opts)
  end

  def ping(pid) do
    GenServer.call(pid, :ping)
  end

  def read(pid) do
    GenServer.call(pid, :read)
  end

  def init(n) do
    {:ok, n}
  end

  def handle_call(:ping, _from, n) do
    {:reply, :ok, n + 1}
  end

  def handle_call(:read, _from, n) do
    {:reply, n, n}
  end
end
