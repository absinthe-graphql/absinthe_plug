defmodule Absinthe.Plug.TestCase do

  defmacro __using__(_) do
    quote do
      use ExUnit.Case, async: true
      use Plug.Test

      import unquote(__MODULE__)
    end
  end

  def call(conn, opts) do
    conn
    |> plug_parser
    |> Absinthe.Plug.call(opts)
    |> Map.update!(:resp_body, &Poison.decode!/1)
  end

  def plug_parser(conn) do
    opts = Plug.Parsers.init(
      parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
      json_decoder: Poison
    )
    Plug.Parsers.call(conn, opts)
  end

end