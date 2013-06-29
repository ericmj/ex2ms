defmodule Ex2ms do
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
    { [], vars }
  end

  defp translate_body(_, _vars) do
    []
  end

  defp translate_head([{ :when, _, [params, conds] }]) do
    { head, vars } = translate_params(params)
    { conds, vars } = translate_conds(conds, vars)
    { head, conds, vars }
  end

  defp translate_head([params]) do
    { head, vars } = translate_params(params)
    { head, [], vars }
  end

  defp translate_params(params) do
    case params do
      { var, _, nil } = t when is_atom(var) ->
        translate_term(t, [])
      { :{}, _, list } = t when is_list(list) ->
        translate_term(t, [])
      { left, right } = t ->
        translate_term(t, [])
      _ ->
        raise ArgumentError, message: "parameters to matchspec has to be a single var or tuple"
    end
  end

  defp translate_term({ var, _, nil }, vars) when is_atom(var) do
    translate_var(var, vars)
  end

  defp translate_term({ left, right }, vars) do
    translate_term({ :{}, [], [left, right] }, vars)
  end

  defp translate_term({ :{}, _, list }, vars) when is_list(list) do
    { list, vars } = Enum.map_reduce(list, vars, translate_term(&1, &2))
    { list_to_tuple(list), vars }
  end

  defp translate_term(list, vars) when is_list(list) do
    Enum.map_reduce(list, vars, translate_term(&1, &2))
  end

  defp translate_term(literal, vars) when is_literal(literal) do
    { literal, vars }
  end

  defp translate_term(unknown, _vars) do
    raise ArgumentError, message: "expected term, got `#{inspect unknown}`"
  end

  defp translate_var(:_, vars) do
    { :_, vars }
  end

  defp translate_var(var, vars) do
    if index = Enum.find_index(vars, var == &1) do
      { :"$#{index+1}", vars }
    else
      { :"$#{length(vars)+1}", vars ++ [var] }
    end
  end
end
