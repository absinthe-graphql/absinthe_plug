# Absinthe.Plug

[![Build Status](https://github.com/absinthe-graphql/absinthe_plug/workflows/CI/badge.svg)](https://github.com/absinthe-graphql/absinthe_plug/actions?query=workflow%3ACI)
[![Version](https://img.shields.io/hexpm/v/absinthe_plug.svg)](https://hex.pm/packages/absinthe_plug)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/absinthe_plug/)
[![Download](https://img.shields.io/hexpm/dt/absinthe_plug.svg)](https://hex.pm/packages/absinthe_plug)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Last Updated](https://img.shields.io/github/last-commit/absinthe-graphql/absinthe_plug.svg)](https://github.com/absinthe-graphql/absinthe_plug/commits/master)

[Plug](https://hex.pm/packages/plug) support for [Absinthe](https://hex.pm/packages/absinthe),
the GraphQL toolkit for Elixir.

Please see the website at [http://absinthe-graphql.org](http://absinthe-graphql.org).

## Installation

Install from [Hex.pm](https://hex.pm/packages/absinthe_plug):

```elixir
def deps do
  [{:absinthe_plug, "~> 1.5"}]
end
```

Note: Absinthe.Plug requires Elixir 1.10 or higher.

`Absinthe.Plug` also requires a JSON codec. `Jason` and `Poison` work out of the box.

```elixir
def deps do
  [
    ...,
    {:absinthe_plug, "~> 1.5"},
    {:jason, "~> 1.0"}
  ]
end
```

## Upgrading

See [CHANGELOG](./CHANGELOG.md) for upgrade steps between versions.

You may want to look for the specific upgrade guide in the [Absinthe documentation](https://hexdocs.pm/absinthe).

## Documentation

See "Usage," below, for basic usage information and links to specific resources.

- [Absinthe.Plug hexdocs](https://hexdocs.pm/absinthe_plug).
- For the tutorial, guides, and general information about Absinthe-related
  projects, see [http://absinthe-graphql.org](http://absinthe-graphql.org).

## Related Projects

See the [GitHub organization](https://github.com/absinthe-graphql).

## Usage

In your `MyAppWeb.Router` module add:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
  pass: ["*/*"],
  json_decoder: Jason

plug Absinthe.Plug,
  schema: MyAppWeb.Schema
```

If you want `Absinthe.Plug` to serve only a particular route, configure your
`MyAppWeb.Router` like:

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

## Community

The project is under constant improvement by a growing list of
contributors, and your feedback is important. Please join us in Slack
(`#absinthe-graphql` under the Elixir Slack account) or the Elixir Forum
(tagged `absinthe`).

Please remember that all interactions in our official spaces follow
our [Code of Conduct](./CODE_OF_CONDUCT.md).

## Contributing

Please follow [contribution guide](./CONTRIBUTING.md).

## License

See [LICENSE.md](./LICENSE.md).
