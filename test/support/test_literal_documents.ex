defmodule Absinthe.Plug.TestLiteralDocuments do
  use Absinthe.Plug.DocumentProvider.Compiled

  provide("1", """
  query FooQuery($id: ID!) {
    item(id: $id) {
      name
    }
  }
  """)

  provide("2", """
  query GetUser {
    user
  }
  """)
end
