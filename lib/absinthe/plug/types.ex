defmodule Absinthe.Plug.Types do
  use Absinthe.Schema.Notation

  alias Absinthe.Blueprint

  @desc """
  This scalar represents an uploaded file.
  """
  scalar :upload do
    parse fn
      %Blueprint.Input.String{value: value}, context ->
        Map.fetch(context[:__absinthe_plug__][:uploads] || %{}, value)
      _, _ ->
        :error
    end

    serialize fn _ ->
      raise "The `:upload` scalar cannot be returned!"
    end
  end
end
