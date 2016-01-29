defmodule Absinthe.Plug.Application do
  use Application

  def start(_, _) do
    import Supervisor.Spec, warn: false
    [
      worker(Absinthe.Plug.Cache, [[name: Absinthe.Plug.Cache]])
    ]
    |> Supervisor.start_link(strategy: :one_for_one)
  end
end
