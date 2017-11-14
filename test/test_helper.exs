ordered = 
  case System.get_env("ABSINTHE_ORDERED") do
    string when string in ["false", "true"] -> String.to_existing_atom(string)
    nil -> nil 
  end

Application.put_env(:absinthe, :ordered, ordered)

IO.inspect ordered, label: "Ordered results"

ExUnit.start()