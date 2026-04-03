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

  ### Standard multipart spec (recommended)

  Absinthe supports the
  [graphql-multipart-request-spec](https://github.com/jaydenseric/graphql-multipart-request-spec),
  which is the standard used by Apollo Client, urql, Relay, and most GraphQL
  client libraries. If you're using any of these clients, file uploads should
  work out of the box with no additional configuration.

  The standard format sends three parts in a `multipart/form-data` request:

  - `operations`: a JSON string with the query and variables (file slots set to `null`)
  - `map`: a JSON object mapping form field names to variable paths
  - `0`, `1`, etc.: the actual files

  For example, using `cURL`:

  ```shell
  $ curl -X POST \\
    -F operations='{"query": "mutation($file: Upload!) { uploadFile(users: $file) { id } }", "variables": {"file": null}}' \\
    -F map='{"0": ["variables.file"]}' \\
    -F 0=@users.csv \\
    localhost:4000/graphql
  ```

  Multiple files work the same way:

  ```shell
  $ curl -X POST \\
    -F operations='{"query": "mutation($a: Upload!, $b: Upload) { uploadFile(users: $a, metadata: $b) { id } }", "variables": {"a": null, "b": null}}' \\
    -F map='{"0": ["variables.a"], "1": ["variables.b"]}' \\
    -F 0=@users.csv \\
    -F 1=@metadata.json \\
    localhost:4000/graphql
  ```

  ### Absinthe's legacy format

  Absinthe also supports its own upload format where the mutation argument
  value is a string that references the form field name containing the file.
  This format continues to work as before:

  ```shell
  $ curl -X POST \\
    -F query='mutation { uploadFile(users: "users_csv", metadata: "metadata_json") }' \\
    -F users_csv=@users.csv \\
    -F metadata_json=@metadata.json \\
    localhost:4000/graphql
  ```

  Note how there is a correspondence between the value of the `:users` argument
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
