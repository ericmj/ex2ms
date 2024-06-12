defmodule Ex2ms do
  @moduledoc """
  This module provides the `Ex2ms.fun/1` macro for translating Elixir functions
  to match specifications.
  """

  @bool_functions [
    :is_atom,
    :is_binary,
    :is_float,
    :is_function,
    :is_integer,
    :is_list,
    :is_map_key,
    :is_number,
    :is_pid,
    :is_port,
    :is_record,
    :is_reference,
    :is_tuple,
    :and,
    :not,
    :or,
    :xor
  ]

  @extra_guard_functions [
    :-,
    :!=,
    :!==,
    :*,
    :/,
    :+,
    :<,
    :<=,
    :==,
    :===,
    :>,
    :>=,
    :abs,
    :band,
    :binary_part,
    :bnot,
    :bor,
    :bsl,
    :bsr,
    :bxor,
    :count,
    :div,
    :element,
    :hd,
    :map_get,
    :max,
    :min,
    :node,
    :rem,
    :round,
    :self,
    :size,
    :tl,
    :trunc
  ]

  @guard_functions @bool_functions ++ @extra_guard_functions

  @action_functions [
    :caller_line,
    :caller,
    :current_stacktrace,
    :disable_trace,
    :display,
    :enable_trace,
    :exception_trace,
    :get_seq_token,
    :message,
    :process_dump,
    :return_trace,
    :set_seq_token,
    :set_tcw,
    :silent,
    :trace
  ]

  @elixir_erlang [
    !=: :"/=",
    !==: :"=/=",
    <=: :"=<",
    ===: :"=:=",
    and: :andalso,
    or: :orelse
  ]

  Enum.each(@guard_functions, fn atom ->
    defp is_guard_function(unquote(atom)), do: true
  end)

  defp is_guard_function(_), do: false

  Enum.each(@action_functions, fn atom ->
    defp is_action_function(unquote(atom)), do: true
  end)

  defp is_action_function(_), do: false

  Enum.each(@elixir_erlang, fn {elixir, erlang} ->
    defp map_elixir_erlang(unquote(elixir)), do: unquote(erlang)
  end)

  defp map_elixir_erlang(atom), do: atom

  @doc """
  Translates an anonymous function to a match specification.

  ## Examples
      iex> Ex2ms.fun do {x, y} -> x == 2 end
      [{{:"$1", :"$2"}, [], [{:==, :"$1", 2}]}]
  """
  defmacro fun(do: clauses) do
    clauses
    |> Enum.map(fn {:->, _, clause} -> translate_clause(clause, __CALLER__) end)
    |> Macro.escape(unquote: true)
  end

  defmacrop is_literal(term) do
    quote do
      is_atom(unquote(term)) or is_number(unquote(term)) or is_binary(unquote(term))
    end
  end

  defp translate_clause([head, body], caller) do
    {head, conds, state} = translate_head(head, caller)

    case head do
      %{} ->
        raise_parameter_error(head)

      _ ->
        body = translate_body(body, state)
        {head, conds, body}
    end
  end

  defp translate_body({:__block__, _, exprs}, state) when is_list(exprs) do
    Enum.map(exprs, &translate_cond(&1, state))
  end

  defp translate_body(expr, state) do
    [translate_cond(expr, state)]
  end

  defp translate_cond({name, _, context}, state) when is_atom(name) and is_atom(context) do
    if match_var = state.vars[{name, context}] do
      :"#{match_var}"
    else
      raise ArgumentError,
        message:
          "variable `#{name}` is unbound in matchspec (use `^` for outer variables and expressions)"
    end
  end

  defp translate_cond({left, right}, state), do: translate_cond({:{}, [], [left, right]}, state)

  defp translate_cond({:{}, _, list}, state) when is_list(list) do
    {list |> Enum.map(&translate_cond(&1, state)) |> List.to_tuple()}
  end

  defp translate_cond({:^, _, [var]}, _state) do
    {:const, {:unquote, [], [var]}}
  end

  defp translate_cond(fun_call = {fun, _, args}, state) when is_atom(fun) and is_list(args) do
    cond do
      is_guard_function(fun) ->
        match_args = Enum.map(args, &translate_cond(&1, state))
        match_fun = map_elixir_erlang(fun)
        [match_fun | match_args] |> List.to_tuple()

      expansion = is_expandable(fun_call, state.caller) ->
        translate_cond(expansion, state)

      is_action_function(fun) ->
        match_args = Enum.map(args, &translate_cond(&1, state))
        [fun | match_args] |> List.to_tuple()

      true ->
        raise_expression_error(fun_call)
    end
  end

  defp translate_cond(list, state) when is_list(list) do
    translate_list(list, state)
  end

  defp translate_cond(literal, _state) when is_literal(literal) do
    literal
  end

  defp translate_cond(expr, _state), do: raise_expression_error(expr)

  defp translate_list([], _state) do
    []
  end

  defp translate_list([{:|, _, [left, right]}], state) do
    left_p = translate_cond(left, state)
    right_p = translate_cond(right, state)
    [left_p | right_p]
  end

  defp translate_list([head | tail], state) do
    head_p = translate_cond(head, state)
    tail_p = translate_list(tail, state)
    [head_p | tail_p]
  end

  defp translate_head([{:when, _, [param, cond]}], caller) do
    {head, state} = translate_param(param, caller)
    cond = translate_cond(cond, state)
    {head, [cond], state}
  end

  defp translate_head([param], caller) do
    {head, state} = translate_param(param, caller)
    {head, [], state}
  end

  defp translate_head(expr, _caller), do: raise_parameter_error(expr)

  defp translate_param(param, caller) do
    param = Macro.expand(param, %{caller | context: :match})

    {param, state} =
      case param do
        {:=, _, [{name, _, context}, param]} when is_atom(name) and is_atom(context) ->
          state = %{vars: %{{name, context} => "$_"}, count: 0, caller: caller}
          {Macro.expand(param, %{caller | context: :match}), state}

        {:=, _, [param, {name, _, context}]} when is_atom(name) and is_atom(context) ->
          state = %{vars: %{{name, context} => "$_"}, count: 0, caller: caller}
          {Macro.expand(param, %{caller | context: :match}), state}

        {name, _, context} when is_atom(name) and is_atom(context) ->
          {param, %{vars: %{}, count: 0, caller: caller}}

        {:{}, _, list} when is_list(list) ->
          {param, %{vars: %{}, count: 0, caller: caller}}

        {:%{}, _, list} when is_list(list) ->
          {param, %{vars: %{}, count: 0, caller: caller}}

        {_, _} ->
          {param, %{vars: %{}, count: 0, caller: caller}}

        _ ->
          raise_parameter_error(param)
      end

    do_translate_param(param, state)
  end

  defp do_translate_param({:_, _, context}, state) when is_atom(context) do
    {:_, state}
  end

  defp do_translate_param({name, _, context}, state) when is_atom(name) and is_atom(context) do
    if match_var = state.vars[{name, context}] do
      {:"#{match_var}", state}
    else
      match_var = "$#{state.count + 1}"

      state = %{
        state
        | vars: Map.put(state.vars, {name, context}, match_var),
          count: state.count + 1
      }

      {:"#{match_var}", state}
    end
  end

  defp do_translate_param({left, right}, state) do
    do_translate_param({:{}, [], [left, right]}, state)
  end

  defp do_translate_param({:{}, _, list}, state) when is_list(list) do
    {list, state} = Enum.map_reduce(list, state, &do_translate_param(&1, &2))
    {List.to_tuple(list), state}
  end

  defp do_translate_param({:^, _, [expr]}, state) do
    {{:unquote, [], [expr]}, state}
  end

  defp do_translate_param(list, state) when is_list(list) do
    Enum.map_reduce(list, state, &do_translate_param(&1, &2))
  end

  defp do_translate_param(literal, state) when is_literal(literal) do
    {literal, state}
  end

  defp do_translate_param({:%{}, _, list}, state) do
    Enum.reduce(list, {%{}, state}, fn {key, value}, {map, state} ->
      {key, key_state} = do_translate_param(key, state)
      {value, value_state} = do_translate_param(value, key_state)
      {Map.put(map, key, value), value_state}
    end)
  end

  defp do_translate_param(expr, _state), do: raise_parameter_error(expr)

  defp is_expandable(ast, env) do
    expansion = Macro.expand_once(ast, env)
    if ast !== expansion, do: expansion, else: false
  end

  defp raise_expression_error(expr) do
    message = "illegal expression in matchspec: #{Macro.to_string(expr)}"
    raise ArgumentError, message: message
  end

  defp raise_parameter_error(expr) do
    message =
      "illegal parameter to matchspec (has to be a single variable or tuple): #{Macro.to_string(expr)}"

    raise ArgumentError, message: message
  end
end
