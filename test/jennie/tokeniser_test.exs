defmodule Jennie.TokeniserTest do
  use ExUnit.Case, async: true

  require Jennie.Tokeniser, as: T

  @opts %{indentation: 0, trim: false}

  describe "Interpolation" do
    test "simple characters" do
      assert T.tokenise("foo", 1, 1, @opts) == {:ok, [{:text, 1, 1, ~c"foo"}, {:eof, 1, 4}]}

      assert T.tokenise("Hello from {Jennie}!", 1, 1, @opts) ==
               {:ok,
                [
                  {:text, 1, 1, ~c"Hello from {Jennie}!"},
                  {:eof, 1, 21}
                ]}
    end

    test "strings with curly brackets" do
      assert T.tokenise("foo {{ bar }}", 1, 1, @opts) ==
               {:ok, [{:text, 1, 1, ~c"foo "}, {:tag, 1, 5, [], ["bar"]}, {:eof, 1, 14}]}

      assert T.tokenise("{{template}}: {{planet}}", 1, 1, @opts) ==
               {:ok,
                [
                  {:tag, 1, 1, [], ["template"]},
                  {:text, 1, 13, ~c": "},
                  {:tag, 1, 15, [], ["planet"]},
                  {:eof, 1, 25}
                ]}
    end

    test "sections provide additional context to the scope" do
      assert T.tokenise("{{#repos}}:\n- {{.}}\n{{/repo}}", 1, 1, @opts) ==
               {:ok,
                [
                  {:tag, 1, 1, ~c"#", ["repos"]},
                  {:text, 1, 11, ~c":\n- "},
                  {:tag, 2, 3, [], ["", ""]},
                  {:text, 2, 8, ~c"\n"},
                  {:tag, 3, 1, ~c"/", ["repo"]},
                  {:eof, 3, 10}
                ]}

      assert T.tokenise("{{#boolean}}This should not be rendered.{{/boolean}}", 1, 1, @opts) ==
               {:ok,
                [
                  {:tag, 1, 1, ~c"#", ["boolean"]},
                  {:text, 1, 13, ~c"This should not be rendered."},
                  {:tag, 1, 41, ~c"/", ["boolean"]},
                  {:eof, 1, 53}
                ]}
    end
  end
end
