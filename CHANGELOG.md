# Changelog

## v1.5.1

- Allow overriding `Absinthe.Plug.DocumentProvider.Compiled` process function.
- Ensure all Absinthe.Plug options are overrideable via the runtime `put_options` function.
- Opt out of the default Transport Batch response nesting with `transport_batch_payload_key: false`.
- Add `Absinthe.Plug.assign_context/2` helper for inserting values into a `conn`'s Absinthe context.

## v1.5.0

- Basically no changes in Absinthe.Plug, but required for Absinthe 1.5 pre-release support
- Chore: Update Plug. Get rid of plug compilation warnings
- Feature: allow to pass a default query to GraphiQL interface

----

## v1.4.6

- Fixes support for newer Phoenix versions.
- Misc bug fixes.
- Breaking Change: when an invalid argument is passed, the return value is now 200 instead of 400
  - This change is to be in line with the GraphQL spec
  - More info: https://github.com/absinthe-graphql/absinthe_plug/issues/195

## v1.4.4

- Bug Fix: Document providers will properly get context now.

## v1.4.3

- Improve socket handling with GraphiQL playground

## v1.4.2

- Reverted some problematic javascript updates added in v1.4.1.

## v1.4.1

- Feature: `before_send:` option. Run a function that can alter the `conn` based on the GraphQL result.
- Chore: Update GraphiQL Workspace and Playground.

## v1.4.0

- Feature: Updated GraphiQL Workspace (`:advanced` interface) to latest version; supports subscriptions.
- Bug Fix: Fix breakage when calling a document provider using `DocumentProvider.Compiled` without passing
  params. (#112)

----

## v1.3.0

- Major rework of the Absinthe.Plug internals, although API stays essentially the same.
- Feature: Supports transport level batching!
- Feature: Document Providers: These enable persisted documents, see the DocumentProvider docs

----

## v1.2.4

- Fix issue with missing `fetch` version in CDN for GraphiQL `:simple` interface.

## v1.2.3

- Plug dependency updated to address https://elixirforum.com/t/security-releases-for-plug/3913
- Support for `:analyze_complexity` and `:max_complexity` options, supporting a new Absinthe v1.2.6 feature. (Thanks, @fishcakez)
- Updated GraphiQL "simple" interface to v0.9.3. (Thanks, @jparise)

## v1.2.2

- Enhancement: Uploaded File support

## v1.2.1

- Add support for the `:root_value` option. As with `:context`, `Absinthe.Plug` will pass the value of `conn.private[:absinthe][:root_value]` to `Absinthe` as the `:root_value` option.
