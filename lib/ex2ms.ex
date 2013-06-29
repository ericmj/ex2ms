defmodule Ex2ms do
  @bool_function [
    :is_atom, :is_float, :is_integer, :is_list, :is_number, :is_pid, :is_port,
    :is_reference, :is_tuple, :is_binary, :is_function, :is_record,
    :and, :or, :not, :xor, :andalso, :orelse ]

  @guard_function @bool_function ++ [
    :abs, :element, :hd, :length, :node, :round, :size, :tl, :trunc, :+, :-, :*,
    :div, :rem, :band, :bor, :bxor, :bnot, :bsl, :bsr, :>, :>=, :<, :<=, :===,
    :==, :!==, :!=, :self ]

  @elixir_erlang [ ===: :"=:=", !==: :"=/=", <=: :"=<" ]

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
    { head, conds, vars } = translate_head(head)
    body = translate_body(body, vars)
    { head, conds, body }
  end

  defp translate_conds(_, vars) do
    []
  end

  defp translate_body(_, _vars) do
    []
  end

  defp translate_head([{ :when, _, [param, conds] }]) do
    { head, vars } = translate_params(param)
    conds= translate_conds(conds, vars)
    { head, conds, vars }
  end

  defp translate_head([param]) do
    { head, vars } = translate_params(param)
    { head, [], vars }
  end

  defp translate_param(param) do
    case param do
      { var, _, nil } when is_atom(var) -> nil
      { :{}, _, list } when is_list(list) -> nil
      { _, _ } -> nil
      _ -> raise ArgumentError, message: "parameters to matchspec has to be a single var or tuple"
    end
    do_translate_param(param, [])
  end

  defp do_translate_param({ :_, _, nil }, vars) do
    { :_, vars }
  end

  defp do_translate_param({ var, _, nil }, vars) when is_atom(var) do
    if index = Enum.find_index(vars, var == &1) do
      { :"$#{index+1}", vars }
    else
      { :"$#{length(vars)+1}", vars ++ [var] }
    end
  end

  defp do_translate_param({ left, right }, vars) do
    do_translate_param({ :{}, [], [left, right] }, vars)
  end

  defp do_translate_param({ :{}, _, list }, vars) when is_list(list) do
    { list, vars } = Enum.map_reduce(list, vars, do_translate_param(&1, &2))
    { list_to_tuple(list), vars }
  end

  defp do_translate_param(list, vars) when is_list(list) do
    Enum.map_reduce(list, vars, do_translate_param(&1, &2))
  end

  defp do_translate_param(literal, vars) when is_literal(literal) do
    { literal, vars }
  end

  defp do_translate_param(unknown, _vars) do
    raise ArgumentError, message: "expected term, got `#{inspect unknown}`"
  end
end
