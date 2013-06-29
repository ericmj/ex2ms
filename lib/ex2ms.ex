defmodule Ex2ms do
  @bool_functions [
    :is_atom, :is_float, :is_integer, :is_list, :is_number, :is_pid, :is_port,
    :is_reference, :is_tuple, :is_binary, :is_function, :is_record,
    :and, :or, :not, :xor, :andalso, :orelse ]

  @guard_functions @bool_functions ++ [
    :abs, :element, :hd, :count, :node, :round, :size, :tl, :trunc, :+, :-, :*,
    :div, :rem, :band, :bor, :bxor, :bnot, :bsl, :bsr, :>, :>=, :<, :<=, :===,
    :==, :!==, :!=, :self ]

  @elixir_erlang [ ===: :"=:=", !==: :"=/=", <=: :"=<" ]

  Enum.map(@guard_functions, fn(atom) ->
    defp is_guard_function(unquote(atom)), do: true
  end)
  defp is_guard_function(_), do: false

  Enum.map(@elixir_erlang, fn({ elixir, erlang }) ->
    defp map_elixir_erlang(unquote(elixir)), do: unquote(erlang)
  end)
  defp map_elixir_erlang(atom), do: atom

  defrecord State, vars: [], count: 0

  defmacro test_fun(block) do
    Macro.escape(block)
  end

  defmacro fun([do: { :->, _, funs }]) do
    Enum.map(funs, fn(fun) -> translate_fun(fun) |> Macro.escape end)
  end

  defmacro fun(_) do
    raise ArgumentError, message: "invalid args to matchspec"
  end

  defmacrop is_literal(term) do
    quote do
      is_atom(unquote(term)) or
      is_number(unquote(term)) or
      is_binary(unquote(term))
    end
  end

  defp translate_fun({ head, _, body }) do
    { head, conds, state } = translate_head(head)
    body = translate_body(body, state)
    { head, conds, body }
  end

  defp translate_body({ :__block__, _, exprs }, state) when is_list(exprs) do
    Enum.map(exprs, translate_cond(&1, state))
  end

  defp translate_body(expr, state) do
    [ translate_cond(expr, state) ]
  end

  defp translate_cond({ var, _, nil }, state) when is_atom(var) do
    if match_var = state.vars[var] do
      :"#{match_var}"
    else
      raise ArgumentError, message: "variable `#{var}` is unbound in matchspec"
    end
  end

  defp translate_cond({ left, right }, state) do
    translate_cond({ :{}, [], [left, right] }, state)
  end

  defp translate_cond({ :{}, [], list }, state) when is_list(list) do
    { Enum.map(list, translate_cond(&1, state)) |> list_to_tuple }
  end

  defp translate_cond({ fun, _, args }, state) when is_atom(fun) and is_list(args) do
    if is_guard_function(fun) do
      match_args = Enum.map(args, translate_cond(&1, state))
      match_fun = map_elixir_erlang(fun)
      [match_fun|match_args] |> list_to_tuple
    else
      raise ArgumentError, message: "illegal function `#{fun}` in matchspec"
    end
  end

  defp translate_cond(list, state) when is_list(list) do
    Enum.map(list, translate_cond(&1, state))
  end

  defp translate_cond(literal, _state) when is_literal(literal) do
    literal
  end

  defp translate_cond(_, _state) do
    raise ArgumentError, message: "illegal expression in matchspec"
  end

  defp translate_head([{ :when, _, [param, cond] }]) do
    { head, state } = translate_param(param)
    cond = translate_cond(cond, state)
    { head, [cond], state }
  end

  defp translate_head([param]) do
    { head, state } = translate_param(param)
    { head, [], state }
  end

  defp translate_param(param) do
    { param, state } = case param do
      { :=, _, [{ var, _, nil }, param] } when is_atom(var) ->
        { param, State[].vars([{ var, "$_" }]) }
      { :=, _, [param, { var, _, nil }] } when is_atom(var) ->
        { param, State[].vars([{ var, "$_" }]) }
      { var, _, nil } when is_atom(var) ->
        { param, State[] }
      { :{}, _, list } when is_list(list) ->
        { param, State[] }
      { _, _ } ->
        { param, State[] }
      _ -> raise ArgumentError, message: "parameters to matchspec has to be a single var or tuple"
    end
    do_translate_param(param, state)
  end

  defp do_translate_param({ :_, _, nil }, state) do
    { :_, state }
  end

  defp do_translate_param({ var, _, nil }, state) when is_atom(var) do
    if match_var = state.vars[var] do
      { :"#{match_var}", state }
    else
      match_var = "$#{state.count+1}"
      state = state
        .update_vars([{var, match_var} | &1])
        .update_count(&1 + 1)
      { :"#{match_var}", state }
    end
  end

  defp do_translate_param({ left, right }, state) do
    do_translate_param({ :{}, [], [left, right] }, state)
  end

  defp do_translate_param({ :{}, _, list }, state) when is_list(list) do
    { list, state } = Enum.map_reduce(list, state, do_translate_param(&1, &2))
    { list_to_tuple(list), state }
  end

  defp do_translate_param(list, state) when is_list(list) do
    Enum.map_reduce(list, state, do_translate_param(&1, &2))
  end

  defp do_translate_param(literal, state) when is_literal(literal) do
    { literal, state }
  end

  defp do_translate_param(unknown, _state) do
    raise ArgumentError, message: "expected term, got `#{inspect unknown}`"
  end
end
