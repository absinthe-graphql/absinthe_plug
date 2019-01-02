# Absinthe Plug

[![Build Status](https://travis-ci.org/absinthe-graphql/absinthe_plug.svg?branch=master
"Build Status")](https://travis-ci.org/absinthe-graphql/absinthe_plug)[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

[Plug](https://hex.pm/packages/plug) support for [Absinthe](https://hex.pm/packages/absinthe),
the GraphQL toolkit for Elixir.

Please see the website at [http://absinthe-graphql.org](http://absinthe-graphql.org).

## Installation

Install from [Hex.pm](https://hex.pm/packages/absinthe_plug):

```elixir
def deps do
  [{:absinthe_plug, "~> 1.4.0"}]
end
```

If using Elixir < 1.4 (or manually managing applications), make sure to add it
to your `applications` configuration in `mix.exs`:

```elixir
def application do
  [applications: [:absinthe_plug]]
end
```

`Absinthe.Plug` also requires a JSON codec. `Jason` and `Poison` work out of the box.

```elixir
def deps do
  [
    ...,
    {:absinthe_plug, "~> 1.4.0"},
    {:jason, "~> 1.1.0"}
  ]
end
```

## Usage

Basic Usage:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
  pass: ["*/*"],
  json_decoder: Jason

plug Absinthe.Plug,
  schema: MyAppWeb.Schema
```

If you want `Absinthe.Plug` to serve only a particular route, configure your
router like:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
  pass: ["*/*"],
  json_decoder: Jason

forward "/api",
  to: Absinthe.Plug,
  init_opts: [schema: MyAppWeb.Schema]
```

For more information, see the API documentation for `Absinthe.Plug`.

### Phoenix.Router

If you are using [Phoenix.Router](https://hexdocs.pm/phoenix/Phoenix.Router.html), `forward` expects different arguments:

#### Plug.Router

```elixir
forward "/graphiql",
  to: Absinthe.Plug.GraphiQL,
  init_opts: [
    schema: MyAppWeb.Schema,
    interface: :simple
  ]
```

#### Phoenix.Router

```elixir
forward "/graphiql",
  Absinthe.Plug.GraphiQL,
  schema: MyAppWeb.Schema,
  interface: :simple
```

For more information see [Phoenix.Router.forward/4](https://hexdocs.pm/phoenix/Phoenix.Router.html#forward/4).


## GraphiQL

To add support for a GraphiQL interface, add a configuration for
`Absinthe.Plug.GraphiQL`:

```elixir
forward "/graphiql",
  to: Absinthe.Plug.GraphiQL,
  init_opts: [schema: MyAppWeb.Schema]
```

See the API documentation for `Absinthe.Plug.GraphiQL` for more information.


## Documentation

See [HexDocs](https://hexdocs.pm/absinthe_plug).

## More Help

- For the tutorial, guides, and general information about Absinthe-related
  projects, see [http://absinthe-graphql.org](http://absinthe-graphql.org).
- Join the [community](http://absinthe-graphql.org/community) of Absinthe users.

## Related Projects

See the project list at <http://absinthe-graphql.org/projects>.

## License

See [LICENSE.md](./LICENSE.md).
