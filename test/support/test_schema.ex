defmodule Absinthe.Plug.TestSchema do
  use Absinthe.Schema

  import_types Absinthe.Plug.Types

  @items %{
    "foo" => %{id: "foo", name: "Foo"},
    "bar" => %{id: "bar", name: "Bar"}
  }

  query do
    field :upload_test, :string do
      arg :file_a, non_null(:upload)
      arg :file_b, :upload

      resolve fn args, _ ->
        arg_keys = Enum.map(args, fn {key, %Plug.Upload{}} -> key end)
        {:ok, arg_keys |> Enum.join(", ")}
      end
    end
    field :item,
      type: :item,
      args: [
        id: [type: non_null(:id)]
      ],
      resolve: fn %{id: item_id}, _ ->
        {:ok, @items[item_id]}
      end

    field :field_on_root_value, :string

    field :complex, :string do
      complexity 100
      resolve fn _, _ ->
        raise "complex string must not be resolved"
      end
    end
  end

  object :item do
    description "A Basic Type"

    field :id, :id
    field :name, :string
  end

  object :author do
    description "An author"

    field :id, :id
    field :first_name, :string
    field :last_name, :string
    field :books, list_of(:book)
  end

  object :book, name: "NonFictionBook" do
    description "A Book"

    field :id, :id
    field :title, :string
    field :isbn, :string
    field :authors, list_of(:author)
  end

end
