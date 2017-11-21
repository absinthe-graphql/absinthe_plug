defmodule Mix.Tasks.Absinthe.Plug.Graphiql.Assets.Remove do
  use Mix.Task

  @shortdoc "Removes GraphiQL assets"

  def run(args) do
    opts = Mix.Absinthe.Plug.GraphiQL.AssetsTask.run(args)
    destroy_directory(opts[:local_directory])
  end

  defp destroy_directory(path) when is_binary(path) do
    Mix.shell.info([:red, "* removing ", :reset, Path.relative_to_cwd(path)])
    File.rm_rf!(path)
  end
end
