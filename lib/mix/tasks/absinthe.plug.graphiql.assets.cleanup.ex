defmodule Mix.Tasks.Absinthe.Plug.Graphiql.Assets.CleanUp do
  use Mix.Task

  @shortdoc """
  Removes GraphiQL assets

  ## Options

  --directory - the directory where the assets were downloaded. Be careful using this command because it uses File.rm_rf! for removing the directory.
  """

  def run(args) do
    opts = Mix.Absinthe.Plug.GraphiQL.AssetsTask.run(args)
    destroy_directory(opts[:directory])
  end

  defp destroy_directory(path) when is_binary(path) do
    Mix.shell.info([:red, "* removing ", :reset, Path.relative_to_cwd(path)])
    File.rm_rf!(path)
  end
end
