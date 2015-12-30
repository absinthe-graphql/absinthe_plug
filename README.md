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

## Usage

### In Elixir

### HTTP Usage@joh

Interaction with the plug is designed to closely match that of the official
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

The plug will first look for each parameter in the URL's query-string:

```
/graphql?query=query+getUser($id:ID){user(id:$id){name}}&variables={"id":"4"}
```

If not found in the query string, it will look in the POST request body, using
the `Content-Type` header.

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

### Roadmap & Contributions

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
