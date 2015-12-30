# Absinthe Plug

[Plug](https://hex.pm/packages/plug) support for [Absinthe](https://hex.pm/packages/absinthe),
an experimental GraphQL API toolkit.

## Installation

Install from [Hex.pm](https://hex.pm/packages/absinthe_plug):

```elixir
def deps do
  [{:absinthe_plug, "~> 0.1.0"}]
end
```

Add it to your `applications` configuration in `mix.exs`:

```elixir
def application do
  [applications: [:absinthe_plug]]
end
```

`AbsinthePlug` also requires a JSON codec. Poison works out of the box.

```elixir
def deps do
  [
    {:absinthe_plug, "~> 0.1.2"},
    {:poison, "~> 1.3.0"}
  ]
end
```

## General Usage

As a plug, `AbsinthePlug` requires very little configuration. If you want to support
`application/x-www-form-urlencoded` or `application/json` you'll need to plug
`Plug.Parsers` first.

Here is an example plug module.

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Poison

plug AbsinthePlug,
  schema: MyApp.Linen.Schema,
  adapter: Absinthe.Adapter.LanguageConventions
```

`AbsinthePlug` requires a `schema:` config. The `LanguageConventions` adapter
allows you to use `snake_case_names` in your schema while still accepting and
returning `camelCaseNames`.

It also takes several options. See [the documentation](https://hexdocs.pm/absinthe_plug/AbsinthePlug.html#init/1)
for the full listing.

## In Phoenix

Here is an example phoenix endpoint that uses `AbsinthePlug`

```elixir
defmodule MyApp.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  # other standard phoenix plugs go here

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug AbsinthePlug,
    schema: MyApp.Schema,
    adapter: Absinthe.Adapter.LanguageConventions
end
```

If you still want to use your phoenix router, you can and it would be plugged
`AbsinthePlug`. However, you must pass a `path: "/path/for/absinthe"` option to
`AbsinthePlug` so it can know which path to respond to. All other paths will be
passed along to plugs farther down the line such as a phoenix router

### HTTP API

How clients interact with the plug over HTTP is designed to closely match that
of the official
[express-graphql](https://github.com/graphql/express-graphql) middleware.

Once installed at a path, the plug will accept requests with the
following parameters:

  * `query` - A string GraphQL document to be executed.

  * `variables` - The runtime values to use for any GraphQL query variables
    as a JSON object.

  * `operationName` - If the provided `query` contains multiple named
    operations, this specifies which operation should be executed. If not
    provided, a 400 error will be returned if the `query` contains multiple
    named operations.

The plug will first look for each parameter in the query string, eg:

```
/graphql?query=query+getUser($id:ID){user(id:$id){name}}&variables={"id":"4"}
```

If not found in the query string, it will look in the POST request body, using
a strategy based on the `Content-Type` header.

For content types `application/json` and `application/x-www-form-urlencoded`,
configure `Plug.Parsers` (or equivalent) to parse the request body before `AbsinthePlug`, eg:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Poison
```

For `application/graphql`, the POST body will be parsed as GraphQL query string,
which provides the `query` parameter. If `variables` or `operationName` are
needed, they should be passed as part of the

## Example

Assuming the following Absinthe schema:

```elixir
defmodule AbsinthePlug.TestSchema do
  use Absinthe.Schema
  alias Absinthe.Type

  # Example data
  @items %{
    "foo" => %{id: "foo", name: "Foo"},
    "bar" => %{id: "bar", name: "Bar"}
  }

  def query do
    %Type.Object{
      fields: fields(
        item: [
          type: :item,
          args: args(
            id: [type: non_null(:string)]
          ),
          resolve: fn %{id: item_id}, _ ->
            {:ok, @items[item_id]}
          end
        ]
      )
    }
  end

  @absinthe :type
  def item do
    %Type.Object{
      description: "An item",
      fields: fields(
        id: [type: :id],
        name: [type: :string]
      )
    }
  end

end

```

And the following plug configuration:

```elixir
  plug AbsinthePlug,
    schema: MyApp.Schema
```

We could retrieve the name of the `"foo"` item a number with this query document:

```
query GetItem($id: ID!) {
  item(id: $id) {
    name
  }
}
```

As long as we pass in `"foo"` for the `id` variable. This would be the result,
in JSON:

```json
{
  "item": {
    "name": "Foo"
  }
}
```

The plug supports making the request a number of ways:

### Via a GET

With a query string:

```
?query=query+GetItem{item(id:foo){name}}&variables={id:"foo"}
```

Due to [varying limits on the maximum size of URLs](http://stackoverflow.com/questions/417142/what-is-the-maximum-length-of-a-url-in-different-browsers), we recommend using one of the POST options below instead, putting the `query` into the body of the request.

## Via an `application/json` POST

With a POST body:

```
{
  "query": "query GetItem($id: ID) { item(id: $id) { name } }",
  "variables": {
    "id": "foo"
  }
}
```

(We could also pull either `query` or `variables` out to the query string, just
as in the [GET example](./README.md#via-a-get).)

## Via an `application/graphql` POST

With a query string:

`?variables={id:"foo"}`

And a POST body:

```
query GetItem($id: ID!) {
  item(id: $id) {
    name
  }
}
```

## Roadmap & Contributions

For a list of specific planned features and version targets, see the
[milestone list](https://github.com/CargoSense/absinthe-plug/milestones).

(If your issue is Absinthe (not Plug) related, please see the
[Absinthe](https://github.com/CargoSense/absinthe) project.)

We welcome issues and pull requests; please see CONTRIBUTING.

## License

BSD License

Copyright (c) CargoSense, Inc.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

 * Neither the name Facebook nor the names of its contributors may be used to
   endorse or promote products derived from this software without specific
   prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
