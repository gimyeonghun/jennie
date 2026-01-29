defmodule Jennie.Tokeniser do
  @spaces [?\s, ?\t]

  def tokenise(bin, line, column, opts) when is_binary(bin) do
    tokenise(String.to_charlist(bin), line, column, opts)
  end

  def tokenise(list, line, column, opts)
      when is_list(list) and is_integer(line) and line >= 0 and is_integer(column) and column >= 0 do
    column = opts.indentation + column

    {list, line, column} =
      (opts.trim && trim_init(list, line, column, opts)) || {list, line, column}

    tokenise(list, line, column, opts, [{line, column}], [])
  end

  defp tokenise(~c"{{" ++ t, line, column, opts, buffer, acc) do
    {marker, t} = retrieve_marker(t)

    case expr(t, line, column + 2 + length(marker), opts, []) do
      {:error, _, _, _} = error ->
        error

      {:ok, expr, new_line, new_column, rest} ->
        {rest, new_line, new_column, buffer} =
          trim_if_needed(rest, new_line, new_column, opts, buffer)

        acc = tokenise_text(buffer, acc)
        final = {:tag, line, column, marker, expr}
        tokenise(rest, new_line, new_column, opts, [{new_line, new_column}], [final | acc])
    end
  end

  defp tokenise(~c"\n" ++ t, line, _column, opts, buffer, acc) do
    tokenise(t, line + 1, opts.indentation + 1, opts, [?\n | buffer], acc)
  end

  defp tokenise([h | t], line, column, opts, buffer, acc) do
    tokenise(t, line, column + 1, opts, [h | buffer], acc)
  end

  defp tokenise([], line, column, _opts, buffer, acc) do
    eof = {:eof, line, column}
    {:ok, Enum.reverse([eof | tokenise_text(buffer, acc)])}
  end

  # Tokenise an expression until }} is found

  defp expr([?}, ?} | t], line, column, _opts, buffer) do
    {:ok, Enum.reverse(buffer), line, column + 2, t}
  end

  defp expr(~c"\n" ++ t, line, _column, opts, buffer) do
    expr(t, line + 1, opts.indentation + 1, opts, [?\n | buffer])
  end

  defp expr([h | t], line, column, opts, buffer) do
    expr(t, line, column + 1, opts, [h | buffer])
  end

  defp expr([], line, column, _opts, _buffer) do
    {:error, line, column, "missing token '}}'"}
  end

  # Retrieve marker for {{

  defp retrieve_marker([marker | t]) when marker in [?#, ?/, ?^] do
    {[marker], t}
  end

  defp retrieve_marker(t) do
    {~c"", t}
  end

  # Tokenise the buffered text by appending
  # it to the given accumulator.

  defp tokenise_text([{_line, _column}], acc) do
    acc
  end

  defp tokenise_text(buffer, acc) do
    [{line, column} | buffer] = Enum.reverse(buffer)
    [{:text, line, column, buffer} | acc]
  end

  defp trim_if_needed(rest, line, column, opts, buffer) do
    if opts.trim do
      buffer = trim_left(buffer, 0)
      {rest, line, column} = trim_right(rest, line, column, 0, opts)
      {rest, line, column, buffer}
    else
      {rest, line, column, buffer}
    end
  end

  defp trim_init([h | t], line, column, opts) when h in @spaces,
    do: trim_init(t, line, column + 1, opts)

  defp trim_init([?\r, ?\n | t], line, _column, opts),
    do: trim_init(t, line + 1, opts.indentation + 1, opts)

  defp trim_init([?\n | t], line, _column, opts),
    do: trim_init(t, line + 1, opts.indentation + 1, opts)

  defp trim_init([?<, ?{ | _] = rest, line, column, _opts),
    do: {rest, line, column}

  defp trim_init(_, _, _, _), do: false

  defp trim_left(buffer, count) do
    case trim_whitespace(buffer, 0) do
      {[?\n, ?\r | rest], _} -> trim_left(rest, count + 1)
      {[?\n | rest], _} -> trim_left(rest, count + 1)
      _ when count > 0 -> [?\n | buffer]
      _ -> buffer
    end
  end

  defp trim_right(rest, line, column, last_column, opts) do
    case trim_whitespace(rest, column) do
      {[?\r, ?\n | rest], column} ->
        trim_right(rest, line + 1, opts.indentation + 1, column + 1, opts)

      {[?\n | rest], column} ->
        trim_right(rest, line + 1, opts.indentation + 1, column, opts)

      {[], column} ->
        {[], line, column}

      _ when last_column > 0 ->
        {[?\n | rest], line - 1, last_column}

      _ ->
        {rest, line, column}
    end
  end

  defp trim_whitespace([h | t], column) when h in @spaces, do: trim_whitespace(t, column + 1)
  defp trim_whitespace(list, column), do: {list, column}
end
