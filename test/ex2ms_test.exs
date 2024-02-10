defmodule Ex2msTest do
  use ExUnit.Case, async: true

  doctest Ex2ms

  require Record
  Record.defrecordp(:user, [:name, :age])

  import TestHelpers
  import Ex2ms

  test "basic" do
    assert (fun do
              x -> x
            end) == [{:"$1", [], [:"$1"]}]
  end

  test "$_" do
    assert (fun do
              {x, y} = z -> z
            end) == [{{:"$1", :"$2"}, [], [:"$_"]}]
  end

  test "gproc" do
    assert (fun do
              {{:n, :l, {:client, id}}, pid, _} -> {id, pid}
            end) == [{{{:n, :l, {:client, :"$1"}}, :"$2", :_}, [], [{{:"$1", :"$2"}}]}]
  end

  test "gproc with bound variables" do
    id = 5

    assert (fun do
              {{:n, :l, {:client, ^id}}, pid, _} -> pid
            end) == [{{{:n, :l, {:client, 5}}, :"$1", :_}, [], [:"$1"]}]
  end

  test "gproc with 3 variables" do
    assert (fun do
              {{:n, :l, {:client, id}}, pid, third} -> {id, pid, third}
            end) == [
             {{{:n, :l, {:client, :"$1"}}, :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
           ]
  end

  test "gproc with 1 variable and 2 bound variables" do
    one = 11
    two = 22

    ms =
      fun do
        {{:n, :l, {:client, ^one}}, pid, ^two} -> {^one, pid}
      end

    self_pid = self()
    assert ms == [{{{:n, :l, {:client, 11}}, :"$1", 22}, [], [{{{:const, 11}, :"$1"}}]}]
    assert {:ok, {one, self_pid}} === :ets.test_ms({{:n, :l, {:client, 11}}, self_pid, two}, ms)
  end

  test "cond" do
    assert (fun do
              x when true -> 0
            end) == [{:"$1", [true], [0]}]

    assert (fun do
              x when true and false -> 0
            end) == [{:"$1", [{:andalso, true, false}], [0]}]
  end

  test "multiple funs" do
    ms =
      fun do
        x -> 0
        y -> y
      end

    assert ms == [{:"$1", [], [0]}, {:"$1", [], [:"$1"]}]
  end

  test "multiple exprs in body" do
    ms =
      fun do
        x ->
          x
          0
      end

    assert ms == [{:"$1", [], [:"$1", 0]}]
  end

  test "guard function" do
    ms =
      fun do
        x when is_list(x) -> x
      end

    assert ms == [{:"$1", [is_list: :"$1"], [:"$1"]}]

    ms =
      fun do
        map when is_map_key(map, :key) -> map
      end

    assert ms == [{:"$1", [{:is_map_key, :"$1", :key}], [:"$1"]}]
  end

  test "invalid guard function" do
    assert_raise ArgumentError, "illegal expression in matchspec: does_not_exist(x)", fn ->
      delay_compile(
        fun do
          x when does_not_exist(x) -> x
        end
      )
    end
  end

  test "custom guard macro" do
    ms =
      fun do
        x when custom_guard(x) -> x
      end

    assert ms == [{:"$1", [{:andalso, {:>, :"$1", 3}, {:"/=", :"$1", 5}}], [:"$1"]}]
  end

  test "nested custom guard macro" do
    ms =
      fun do
        x when nested_custom_guard(x) -> x
      end

    assert ms == [
             {
               :"$1",
               [
                 {
                   :andalso,
                   {:andalso, {:>, :"$1", 3}, {:"/=", :"$1", 5}},
                   {:andalso, {:>, {:+, :"$1", 1}, 3}, {:"/=", {:+, :"$1", 1}, 5}}
                 }
               ],
               [:"$1"]
             }
           ]
  end

  test "map is illegal alone in body" do
    assert_raise ArgumentError, "illegal expression in matchspec: %{x: z}", fn ->
      delay_compile(
        fun do
          {x, z} -> %{x: z}
        end
      )
    end
  end

  test "map in head tuple" do
    ms =
      fun do
        {x, %{a: y, c: z}} -> {y, z}
      end

    assert ms == [{{:"$1", %{a: :"$2", c: :"$3"}}, [], [{{:"$2", :"$3"}}]}]
  end

  test "map is not allowed in the head of function" do
    assert_raise ArgumentError,
                 "illegal parameter to matchspec (has to be a single variable or tuple): %{x: :\"$1\"}",
                 fn ->
                   delay_compile(
                     fun do
                       %{x: z} -> z
                     end
                   )
                 end
  end

  test "invalid fun args" do
    assert_raise FunctionClauseError, fn ->
      delay_compile(fun(123))
    end
  end

  test "raise on invalid fun head" do
    assert_raise ArgumentError,
                 "illegal parameter to matchspec (has to be a single variable or tuple): [x, y]",
                 fn ->
                   delay_compile(
                     fun do
                       x, y -> 0
                     end
                   )
                 end

    assert_raise ArgumentError,
                 "illegal parameter to matchspec (has to be a single variable or tuple): y = z",
                 fn ->
                   delay_compile(
                     fun do
                       {x, y = z} -> 0
                     end
                   )
                 end

    assert_raise ArgumentError,
                 "illegal parameter to matchspec (has to be a single variable or tuple): 123",
                 fn ->
                   delay_compile(
                     fun do
                       123 -> 0
                     end
                   )
                 end
  end

  test "unbound variable" do
    assert_raise ArgumentError,
                 "variable `y` is unbound in matchspec (use `^` for outer variables and expressions)",
                 fn ->
                   delay_compile(
                     fun do
                       x -> y
                     end
                   )
                 end
  end

  test "invalid expression" do
    assert_raise ArgumentError, "illegal expression in matchspec: x = y", fn ->
      delay_compile(
        fun do
          x -> x = y
        end
      )
    end

    assert_raise ArgumentError, "illegal expression in matchspec: abc(x)", fn ->
      delay_compile(
        fun do
          x -> abc(x)
        end
      )
    end
  end

  test "record" do
    ms =
      fun do
        user(age: x) = n when x > 18 -> n
      end

    assert ms == [{{:user, :_, :"$1"}, [{:>, :"$1", 18}], [:"$_"]}]

    x = 18

    ms =
      fun do
        user(name: name, age: ^x) -> name
      end

    assert ms == [{{:user, :"$1", 18}, [], [:"$1"]}]

    # Records nils will be converted to :_, if nils are needed, we should explicitly match on it
    ms =
      fun do
        user(age: age) = n when age == nil -> n
      end

    assert ms == [{{:user, :_, :"$1"}, [{:==, :"$1", nil}], [:"$_"]}]
  end

  test "action function" do
    ms =
      fun do
        _ -> return_trace()
      end

    assert ms == [{:_, [], [{:return_trace}]}]

    # action functions with arguments get turned into :atom, args... tuples
    ms =
      fun do
        arg when arg == :foo -> set_seq_token(:label, :foo)
      end

    assert ms == [{:"$1", [{:==, :"$1", :foo}], [{:set_seq_token, :label, :foo}]}]
  end

  test "composite bound variables in guards" do
    one = {1, 2, 3}

    ms =
      fun do
        arg when arg < ^one -> arg
      end

    assert ms == [{:"$1", [{:<, :"$1", {:const, {1, 2, 3}}}], [:"$1"]}]
  end

  test "composite bound variables in return value" do
    bound = {1, 2, 3}

    ms =
      fun do
        arg -> {^bound, arg}
      end

    assert ms == [{:"$1", [], [{{{:const, {1, 2, 3}}, :"$1"}}]}]
    assert {:ok, {bound, {:some, :record}}} === :ets.test_ms({:some, :record}, ms)
  end

  test "outer expressions get evaluated" do
    ms =
      fun do
        arg -> {^{1, 1 + 1, 3}, arg}
      end

    assert ms == [{:"$1", [], [{{{:const, {1, 2, 3}}, :"$1"}}]}]
  end

  defmacro test_contexts(var) do
    quote do
      var = {1, 2, 3}

      fun do
        {^var, _} -> ^unquote(var)
      end
    end
  end

  test "contexts are preserved" do
    var = 42
    ms = test_contexts(var)

    assert {:ok, 42} === :ets.test_ms({{1, 2, 3}, 123}, ms)
  end

  test "cons cells are working" do
    ms =
      fun do
        {k, l} when is_list(l) -> {k, [:marker | l]}
      end

    assert ms == [{{:"$1", :"$2"}, [is_list: :"$2"], [{{:"$1", [:marker | :"$2"]}}]}]
  end

  test "binary_part" do
    prefix = "1234"

    ms =
      fun do
        bid when binary_part(bid, 0, 4) == ^prefix -> bid
      end

    assert ms == [{:"$1", [{:==, {:binary_part, :"$1", 0, 4}, {:const, prefix}}], [:"$1"]}]
    assert {:ok, "12345"} == :ets.test_ms("12345", ms)
  end
end
