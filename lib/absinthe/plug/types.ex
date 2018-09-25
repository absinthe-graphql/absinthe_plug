defmodule Absinthe.Plug.Types do
  @moduledoc """
  This module provides GraphQL types that may be useful in Absinthe schema
  and type modules.

  ## `:upload`

  Absinthe.Plug can be used to upload files via GraphQL.

  For example, the following schema includes a mutation field that accepts
  multiple uploaded files as arguments (`:users` and `:metadata`):

  ```elixir
  defmodule MyAppWeb.Schema do
    use Absinthe.Schema

    # Important: Needed to get the `:upload` type
    import_types Absinthe.Plug.Types

    mutation do
      field :upload_file, :string do
        arg :users, non_null(:upload)
        arg :metadata, :upload

        resolve fn args, _ ->
          args.users # this is a `%Plug.Upload{}` struct.

          {:ok, "success"}
        end
      end
    end
  end
  ```

  To send a mutation that includes a file upload, you need to
  use the `multipart/form-data` content type. For example, using `cURL`:

  ```shell
  $ curl -X POST \
  -F query='mutation { uploadFile(users: "users_csv", metadata: "metadata_json") }' \
  -F users_csv=@users.csv \
  -F metadata_json=@metadata.json \
  localhost:4000/graphql
  ```

  Note how there is a correspondance between the value of the `:users` argument
  and the `-F` option indicating the associated file.

  By treating uploads as regular arguments we get all the usual GraphQL argument
  benefits (such as validation and documentation), something we wouldn't get if
  we were merely putting them in the context.
  """

  use Absinthe.Schema.Notation

  alias Absinthe.Blueprint

  @desc """
  Represents an uploaded file.
  """
  scalar :upload do
    parse fn
      %Blueprint.Input.String{value: value}, context ->
        Map.fetch(context[:__absinthe_plug__][:uploads] || %{}, value)
      %Blueprint.Input.Null{}, _ ->
        {:ok, nil}
      _, _ ->
        :error
    end

    serialize fn _ ->
      raise "The `:upload` scalar cannot be returned!"
    end
  end
end
