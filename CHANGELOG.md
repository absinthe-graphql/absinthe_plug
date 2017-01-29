v1.2.2
- Enhancement: Uploaded File support

v1.2.1
- Add support for the `:root_value` option. As with `:context`, `Absinthe.Plug`
will pass the value of `conn.private[:absinthe][:root_value]` to `Absinthe` as the `:root_value` option.
