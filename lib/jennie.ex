defmodule Jennie do
  def render(source, data \\ %{}) do
    Jennie.Compiler.compile(source, data, trim: true)
  end
end
