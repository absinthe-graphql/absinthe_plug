v1.3.0-beta0

- Use configurable logging provided by `Absinthe.Logger` (which supports variable
  logging/filtering).
  - Add Document Providers with support for "compiled," partially pre-processed
  GraphQL documents. Read the documentation for `Absinthe.Plug.DocumentProvider`
  and `Absinthe.Plug.DocumentProvider.Compiled` for more information.

v1.2.4

- Fix issue with missing `fetch` version in CDN for GraphiQL `:simple` interface.

v1.2.3

- Plug dependency updated to address https://elixirforum.com/t/security-releases-for-plug/3913
- Support for `:analyze_complexity` and `:max_complexity` options, supporting a new Absinthe v1.2.6 feature. (Thanks, @fishcakez)
- Updated GraphiQL "simple" interface to v0.9.3. (Thanks, @jparise)

v1.2.2

- Enhancement: Uploaded File support

v1.2.1

- Add support for the `:root_value` option. As with `:context`, `Absinthe.Plug`
will pass the value of `conn.private[:absinthe][:root_value]` to `Absinthe` as the `:root_value` option.
