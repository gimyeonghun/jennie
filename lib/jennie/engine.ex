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

  def handle_tag(state, meta, expr, data) do
    check_state!(state)
    %{binary: binary} = state

    eval = handle_assigns(expr, data)

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

  defp fetch_assigns(container, field) do
    key = :erlang.list_to_binary(Enum.reverse(field))
    Access.get(container, key)
  end

  # Entry into `handle_assigns/3`
  defp handle_assigns(chars, assigns)
       when is_list(chars) and is_map(assigns) do
    handle_assigns(chars, assigns, [])
  end

  defp handle_assigns(~c"." ++ rest, assigns, acc) do
    value = fetch_assigns(assigns, acc)

    if value == nil do
      # No point attempting to continue lookup
      handle_assigns(rest, %{}, [])
    else
      handle_assigns(rest, value, [])
    end
  end

  # Terminate lookup
  defp handle_assigns(~c"", assigns, acc) do
    fetch_assigns(assigns, acc) || ""
  end

  defp handle_assigns([h | rest], assigns, acc) do
    handle_assigns(rest, assigns, [h | acc])
  end
end
