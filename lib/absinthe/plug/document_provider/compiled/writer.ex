defmodule Absinthe.Plug.DocumentProvider.Compiled.Writer do
  @moduledoc false

  defmacro write(env) do
    [
      quoted_compiled_lookups(env),
      quoted_source_lookups(env),
      quoted_lookup_fallthrough(),
      quoted_pipeline_tools()
    ]
  end

  @doc false
  def error_message(id, module, messages) do
    messages = List.wrap(messages)
    "\n\n" <> """
    Could not compile document provider #{module}.

    The following problems were found processing document "#{id}":
    """ <> Enum.join(Enum.map(messages, &"  - #{&1}"), "\n") <> "\n"
  end

  @spec quoted_compiled_lookups(Macro.Env.t) :: Macro.t
  defp quoted_compiled_lookups(env) do
    docs = Module.get_attribute(env.module, :absinthe_documents_to_compile)
    compilation_pipeline = Module.get_attribute(env.module, :compilation_pipeline)
    for {id, document_text} <- docs do
      pipeline = compilation_pipeline ++ [
        {Absinthe.Plug.DocumentProvider.Compiled.Check, id: id, module: env.module}
      ]
      case Absinthe.Pipeline.run(document_text, pipeline) do
        {:ok, result, _} ->
          document = Macro.escape(result)
          quote do
            def __absinthe_plug_doc__(:compiled, unquote(id)), do: unquote(document)
          end
        {:error, message, _} ->
          raise error_message(id, env.module, message)
      end
    end
  end

  @spec quoted_source_lookups(Macro.Env.t) :: Macro.t
  defp quoted_source_lookups(env) do
    docs = Module.get_attribute(env.module, :absinthe_documents_to_compile)
    for {id, document_text} <- docs do
      quote do
        def __absinthe_plug_doc__(:source, unquote(id)), do: unquote(document_text)
      end
    end
  end

  @spec quoted_lookup_fallthrough() :: Macro.t
  defp quoted_lookup_fallthrough() do
    quote do
      def __absinthe_plug_doc__(_, _), do: nil
    end
  end

  @spec quoted_pipeline_tools() :: Macro.t
  defp quoted_pipeline_tools() do
    quote do
      def __absinthe_plug_doc__(:remaining_pipeline) do
        @compilation_pipeline
        |> List.last
        |> case do
          {mod, _} ->
            mod
          mod ->
            mod
        end
      end
    end
  end

end