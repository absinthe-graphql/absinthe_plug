# Absinthe Plug

[![Build Status](https://travis-ci.org/absinthe-graphql/absinthe_plug.svg?branch=master
"Build Status")](https://travis-ci.org/absinthe-graphql/absinthe_plug)

[Plug](https://hex.pm/packages/plug) support for [Absinthe](https://hex.pm/packages/absinthe),
the GraphQL toolkit for Elixir.

Please see the website at [http://absinthe-graphql.org](http://absinthe-graphql.org).

## Installation

Install from [Hex.pm](https://hex.pm/packages/absinthe_plug):

```elixir
def deps do
  [{:absinthe_plug, "~> 1.3.0-rc.0"}]
end
```

If using Elixir < 1.4 (or manually managing applications), make sure to add it
to your `applications` configuration in `mix.exs`:

```elixir
def application do
  [applications: [:absinthe_plug]]
end
```

`Absinthe.Plug` also requires a JSON codec. Poison works out of the box.

```elixir
def deps do
  [
<<<<<<< HEAD
    ...,
=======
    {:absinthe_plug, "~> 1.2.3"},
>>>>>>> master
    {:poison, "~> 1.3.0"}
  ]
end
```

## Usage

Basic Usage:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
  pass: ["*/*"],
  json_decoder: Poison

plug Absinthe.Plug,
  schema: MyApp.Schema

If you want only `Absinthe.Plug` to serve a particular route, configure your
router like:

plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
  pass: ["*/*"],
  json_decoder: Poison

forward "/api", Absinthe.Plug,
  schema: MyApp.Schema

For more information, see the API documentation for `Absinthe.Plug`.

## GraphiQL

To add support for a GraphiQL interface, add a configuration for
`Absinthe.Plug.GraphiQL`:

```elixir
forward "/graphiql",
  Absinthe.Plug.GraphiQL,
  schema: MyApp.Schema,
```

See the API documentation for `Absinthe.Plug.GraphiQL` for more information.

## More Help

- For the tutorial, guides, and general information about Absinthe-related
  projects, see [http://absinthe-graphql.org](http://absinthe-graphql.org).
- Join the [community](http://absinthe-graphql.org/community) of Absinthe users.

## Related Projects

See the project list at <http://absinthe-graphql.org/projects>.

## License

See `LICENSE`.
