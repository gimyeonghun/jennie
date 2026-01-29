defmodule Jennie.Compiler do
  @default_engine Jennie.Engine

  def compile(source, data, opts) do
    line = opts[:line] || 1
    column = 1
    indentation = opts[:indentation] || 0
    trim = opts[:trim] || false

    tokeniser_options = %{trim: trim, indentation: indentation}

    case Jennie.Tokeniser.tokenise(source, line, column, tokeniser_options) do
      {:ok, tokens} ->
        state = %{
          engine: opts[:engine] || @default_engine,
          line: line,
          start_line: line,
          start_column: column,
          data: data
        }

        init = state.engine.init(opts)

        generate_buffer(tokens, init, [], state)

      {:error, line, column, message} ->
        raise Jennie.SyntaxError,
          message: message,
          line: line,
          column: column
    end
  end

  defp generate_buffer([{:text, line, column, chars} | rest], buffer, scope, state) do
    meta = [line: line, column: column]

    buffer = state.engine.handle_text(buffer, meta, chars)

    generate_buffer(rest, buffer, scope, state)
  end

  defp generate_buffer([{:tag, line, column, _mark, chars} | rest], buffer, scope, state) do
    meta = [line: line, column: column]

    buffer = state.engine.handle_tag(buffer, meta, chars, state.data)

    generate_buffer(rest, buffer, scope, state)
  end

  defp generate_buffer([{:eof, _, _}], buffer, [], state) do
    state.engine.handle_body(buffer)
  end

  defp generate_buffer([{:eof, line, column}], _buffer, _scope, _state) do
    raise Jennie.SyntaxError,
      message: "unexpected end of string, expected a closing {{/<thing>}}",
      line: line,
      column: column
  end
end
