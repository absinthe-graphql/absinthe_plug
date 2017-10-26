defmodule Absinthe.Plug.TestPubSub do
  @behaviour Absinthe.Subscription.Pubsub

  def start_link() do
    Registry.start_link(:unique, __MODULE__)
  end

  def subscribe(topic) do
    Registry.register(__MODULE__, topic, [])
    :ok
  end

  def publish_subscription(topic, data) do
    message = %{topic: topic, event: "subscription:data", result: data}
    Registry.dispatch(__MODULE__, topic, fn entries ->
      for {pid, _} <- entries, do: send(pid, message)
    end)
  end

  def publish_mutation(_proxy_topic, _mutation_result, _subscribed_fields) do
    # this pubsub is local and doesn't support clusters
    :ok
  end
end
