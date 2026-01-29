defmodule Jennie.Engine do
  @moduledoc """
  Engine that actions on Jennie tokens
  """

  defstruct ~w(binary vars non_null_context)a

  def init(_opts) do
    %__MODULE__{
      binary: [],
      vars: [],
      non_null_context: true
    }
  end

  def reset_context(state), do: %{state | non_null_context: true}

  def handle_text(state, text) do
    check_state!(state)
    %{binary: binary, non_null_context: context?} = state
    if context?, do: %{state | binary: [text | binary]}, else: state
  end

  def handle_tag(state, {line, column}, expr, %{assigns: assigns, scope: scope}) do
    check_state!(state)
    %{binary: binary} = state

    eval = handle_assigns(assigns, scope, expr)

    if is_map(eval) do
      expr = :erlang.list_to_binary(expr)

      raise Jennie.SyntaxError,
        message: "Incomplete expansion of tag `#{expr}`.",
        line: line,
        column: column
    end

    %{state | binary: [to_charlist(eval) | binary]}
  end

  def handle_context(state, {_, _}, expr, %{assigns: assigns, scope: scope}) do
    check_state!(state)

    eval_context = handle_assigns(assigns, scope, expr)

    %{state | non_null_context: eval_context}
  end

  defp handle_assigns(assigns, scope, expr),
    do: get_in(assigns, scope ++ expr) || get_in(assigns, expr)

  def handle_body(state) do
    check_state!(state)
    %{binary: binary} = state

    :erlang.list_to_binary(Enum.reverse(binary))
  end

  # Validate that we're passing around THE ENGINE, not something lame
  defp check_state!(%__MODULE__{}), do: :ok

  defp check_state!(state) do
    raise "unexpected Jennie.Engine state: #{inspect(state)}." <>
            "This means either there's a bug or an outdated Jennie Engine"
  end
end
