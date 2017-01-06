defmodule Absinthe.Plug.Batch.PutQueryId do
  @moduledoc false

  alias Absinthe.{Blueprint, Phase}

  use Absinthe.Phase

  @spec run(Blueprint.t, Keyword.t) :: Phase.Blueprint.t
  def run(blueprint, options \\ []) do
    bp_with_query_id = 
      Absinthe.Blueprint.put_flag(blueprint, :query_id, Keyword.get(options, :query_id))

    {:ok, bp_with_query_id}
  end
end
