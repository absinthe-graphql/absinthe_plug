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
  [{:absinthe_plug, "~> 1.2.3"}]
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
    {:absinthe_plug, "~> 1.2.3"},
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
