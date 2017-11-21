defmodule Absinthe.GraphiQL.Validation.NoSubscriptionOnHTTP do
  @moduledoc false

  use Absinthe.Phase

  alias Absinthe.Blueprint

  def run(blueprint, _) do
    case Blueprint.current_operation(blueprint) do
      %{type: :subscription} ->
        {:error, {:http_method, "Subscriptions cannot be run over HTTP. Please configure a websocket connection"}}
      _ ->
        {:ok, blueprint}
    end
  end

end
