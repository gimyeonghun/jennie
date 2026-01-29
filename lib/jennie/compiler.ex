defmodule Jennie.Compiler do
  @default_engine Jennie.Engine

  def compile(source, assigns, opts) do
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
          assigns: assigns
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

  defp generate_buffer([{:tag, line, column, ~c"", chars} | rest], buffer, scope, state) do
    meta = [line: line, column: column]

    buffer = state.engine.handle_tag(buffer, meta, chars, scope, state.assigns)

    generate_buffer(rest, buffer, scope, state)
  end

  defp generate_buffer([{:tag, _line, _column, ~c"#", chars} | rest], buffer, scope, state) do
    section = IO.chardata_to_string(chars)
    generate_buffer(rest, buffer, [section | scope], state)
  end

  defp generate_buffer([{:tag, line, column, ~c"/", _} | _], _buffer, scope, _state)
       when length(scope) == 0 do
    raise Jennie.SyntaxError,
      message: "Cannot close section, because corresponding opening section is missing",
      line: line,
      column: column
  end

  defp generate_buffer([{:tag, line, column, ~c"/", chars} | rest], buffer, [h | t], state) do
    if h == IO.chardata_to_string(chars) do
      generate_buffer(rest, buffer, t, state)
    else
      raise Jennie.SyntaxError,
        message: "Closing section prematurely",
        line: line,
        column: column
    end
  end

  defp generate_buffer([{:eof, line, column}], _buffer, scope, _state) when length(scope) > 0 do
    raise Jennie.SyntaxError,
      message: "A section tag is still open",
      line: line,
      column: column
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
