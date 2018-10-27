v1.4.6

- Fixes support for newer Phoenix versions.
- Misc bug fixes.

v1.4.4

- Bug Fix: Document providers will properly get context now.

v1.4.3

- Improve socket handling with GraphiQL playground

v1.4.2

- Reverted some problematic javascript updates added in v1.4.1.

v1.4.1

- Feature: `before_send:` option. Run a function that can alter the `conn` based on the GraphQL result.
- Chore: Update GraphiQL Workspace and Playground.

v1.4.0

Status: RC

- Feature: Updated GraphiQL Workspace (`:advanced` interface) to latest version; supports subscriptions.
- Bug Fix: Fix breakage when calling a document provider using `DocumentProvider.Compiled` without passing
  params. (#112)

v1.3.0

- Major rework of the Absinthe.Plug internals, although API stays essentially the same.
- Feature: Supports transport level batching!
- Feature: Document Providers: These enable persisted documents, see the DocumentProvider docs

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
