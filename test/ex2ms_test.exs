defmodule Ex2msTest do
  use ExUnit.Case, async: true

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
    assert_raise ArgumentError, "illegal expression in matchspec:\n%{x: z}", fn ->
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
                 "illegal parameter to matchspec (has to be a single variable or tuple):\n%{x: :\"$1\"}",
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
                 "illegal parameter to matchspec (has to be a single variable or tuple):\n[x, y]",
                 fn ->
                   delay_compile(
                     fun do
                       x, y -> 0
                     end
                   )
                 end

    assert_raise ArgumentError,
                 "illegal parameter to matchspec (has to be a single variable or tuple):\ny = z",
                 fn ->
                   delay_compile(
                     fun do
                       {x, y = z} -> 0
                     end
                   )
                 end

    assert_raise ArgumentError,
                 "illegal parameter to matchspec (has to be a single variable or tuple):\n123",
                 fn ->
                   delay_compile(
                     fun do
                       123 -> 0
                     end
                   )
                 end
  end

  test "outer bound variable" do
    y = 123
    assert (fun do
              x -> y
            end) == [{:"$1", [], [123]}]
  end

  test "unbound variable" do
    assert_raise ArgumentError, "variable `y` is unbound", fn ->
      delay_compile(
        fun do
          x -> y
        end
      )
    end
  end

  test "invalid expression" do
    assert_raise ArgumentError, "illegal expression in matchspec:\nx = y", fn ->
      delay_compile(
        fun do
          x -> x = y
        end
      )
    end

    assert_raise ArgumentError, "illegal expression in matchspec:\nabc(x)", fn ->
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

  doctest Ex2ms
end
