defmodule Jennie.Engine do
  @moduledoc """
  Engine that actions on Jennie tokens
  """

  defstruct ~w(binary vars)a

  def init(_opts) do
    %__MODULE__{
      binary: [],
      vars: []
    }
  end

  def handle_text(state, _meta, text) do
    check_state!(state)
    %{binary: binary} = state
    %{state | binary: [text | binary]}
  end

  def handle_tag(state, meta, expr, scope, assigns) do
    check_state!(state)
    %{binary: binary} = state

    eval = handle_assigns(expr, scope, assigns)

    if is_map(eval) do
      expr = :erlang.list_to_binary(expr)

      raise Jennie.SyntaxError,
        message: "Incomplete expansion of tag `#{expr}`.",
        line: meta[:line],
        column: meta[:column]
    end

    %{state | binary: [to_charlist(eval) | binary]}
  end

  def handle_engine(state, meta, expr, scope, assigns) do
    check_state!(state)
    %{binary: binary} = state

    eval = handle_assigns(expr, scope, assigns)

    if is_map(eval) do
      expr = :erlang.list_to_binary(expr)

      raise Jennie.SyntaxError,
        message: "Incomplete expansion of tag `#{expr}`.",
        line: meta[:line],
        column: meta[:column]
    end

    %{state | binary: [to_charlist(eval) | binary]}
  end

  def handle_body(state) do
    check_state!(state)
    %{binary: binary} = state

    :erlang.list_to_binary(Enum.reverse(binary))
  end

  # Validate that we're passing around THE ENGINE, not something lame
  defp check_state!(%__MODULE{binary: _, vars: _}), do: :ok

  defp check_state!(state) do
    raise "unexpected Jennie.Engine state: #{inspect(state)}." <>
            "This means either there's a bug or an outdated Jennie Engine"
  end

  defp fetch_assigns(container, field) when is_binary(field), do: Access.get(container, field)

  defp fetch_assigns(container, field) do
    key = :erlang.list_to_binary(Enum.reverse(field))
    fetch_assigns(container, key)
  end

  # Entry into `handle_assigns/4`
  defp handle_assigns(chars, [], assigns)
       when is_list(chars) and is_map(assigns) do
    handle_assigns(chars, assigns, [], [])
  end

  defp handle_assigns(~c".", [], assigns)
       when is_map(assigns) do
    fetch_assigns(assigns, "default")
  end

  defp handle_assigns(~c".", scope, assigns)
       when is_map(assigns) do
    fetch_assigns(assigns, scope)
  end

  defp handle_assigns(chars, scope, assigns)
       when is_list(chars) and is_list(scope) and is_map(assigns) do
    handle_assigns(chars, assigns, scope, [])
  end

  defp handle_assigns(~c"." ++ rest, assigns, scope, acc) do
    value = fetch_assigns(assigns, acc)

    if value == nil do
      # No point attempting to continue lookup
      handle_assigns(rest, %{}, scope, [])
    else
      handle_assigns(rest, value, scope, [])
    end
  end

  # Terminate lookup
  defp handle_assigns(~c"", assigns, [], acc) do
    fetch_assigns(assigns, acc) || ""
  end

  defp handle_assigns(~c"", assigns, scope, acc) do
    value =
      assigns
      |> fetch_assigns(scope)
      |> fetch_assigns(acc)

    if value == nil do
      [_ | rest] = scope
      handle_assigns(Enum.reverse(acc), assigns, rest, [])
    else
      value
    end
  end

  defp handle_assigns([h | rest], assigns, scope, acc) do
    handle_assigns(rest, assigns, scope, [h | acc])
  end
end
