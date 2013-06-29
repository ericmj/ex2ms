defmodule Ex2ms do
  @bool_function [
    :is_atom, :is_float, :is_integer, :is_list, :is_number, :is_pid, :is_port,
    :is_reference, :is_tuple, :is_binary, :is_function, :is_record,
    :and, :or, :not, :xor, :andalso, :orelse ]

  @guard_function @bool_function ++ [
    :abs, :element, :hd, :count, :node, :round, :size, :tl, :trunc, :+, :-, :*,
    :div, :rem, :band, :bor, :bxor, :bnot, :bsl, :bsr, :>, :>=, :<, :<=, :===,
    :==, :!==, :!=, :self ]

  @elixir_erlang [ ===: :"=:=", !==: :"=/=", <=: :"=<" ]

  defrecord State, vars: [], count: 0

  defmacro test_fun(block) do
    Macro.escape(block)
  end

  defmacro fun([do: { :->, _, funs }]) do
    Enum.map(funs, fn(fun) -> translate_fun(fun) |> Macro.escape end)
  end

  defmacro fun(_) do
    raise ArgumentError, message: "invalid args to fun"
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

  defp translate_body(_, _state) do
    []
  end

  defp translate_conds(_, _state) do
    []
  end

  defp translate_head([{ :when, _, [param, conds] }]) do
    { head, state } = translate_param(param)
    conds= translate_conds(conds, state)
    { head, conds, state }
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
