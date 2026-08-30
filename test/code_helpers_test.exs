# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.CodeHelpersTest do
  use ExUnit.Case

  import Spark.CodeHelpers

  def decorate_lifted_function(function, key, caller, context, marker) do
    quote do
      unquote(function)
      {unquote(marker), unquote(key), unquote(caller.module), unquote(context.entity_name)}
    end
  end

  test "it generates functions properly when `when` is used in a multi-clausal function" do
    {code, funs} =
      lift_functions(
        quote do
          fn
            %{context: %{error: error}} = changeset, _context when not is_nil(error) ->
              {:error, error}

            changeset, _context ->
              changeset
          end
        end,
        :key,
        __ENV__
      )

    {:module, module, _, _} =
      Module.create(
        Foo,
        quote do
          unquote(funs)

          def fun, do: unquote(code)
        end,
        Macro.Env.location(__ENV__)
      )

    assert :erlang.fun_info(module.fun())[:arity] == 2
  end

  test "a lifted function can be transformed through a generic entity hook" do
    function = quote(do: def(run(value), do: value))

    transformed =
      transform_lifted_function(
        function,
        :run,
        {__MODULE__, :decorate_lifted_function, [:transformed]},
        __ENV__,
        %{entity_name: :operation}
      )

    rendered = Macro.to_string(transformed)

    assert rendered =~ "def run(value)"
    assert rendered =~ "{:transformed, :run, Spark.CodeHelpersTest, :operation}"
  end
end
