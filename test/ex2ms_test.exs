Code.require_file "test_helper.exs", __DIR__

defmodule Ex2msTest do
  use ExUnit.Case, async: true

  import TestHelpers
  import Ex2ms

  test "basic" do
    assert (fun do x -> x end) ==
           [{ :"$1", [], [:"$1"] }]
  end

  test "$_" do
    assert (fun do {x,y}=z -> z end) ==
           [{{ :"$1", :"$2" }, [], [:"$_"] }]
  end

  test "cond" do
    assert (fun do x when true -> 0 end) ==
           [{:"$1", [true], [0] }]

    assert (fun do x when true and false -> 0 end) ==
           [{:"$1", [{ :andalso, true, false }], [0] }]
  end

  test "multiple funs" do
    ms = fun do
      x -> 0
      y -> y
    end
    assert ms == [{:"$1", [], [0] }, {:"$1", [], [:"$1"] }]
  end

  test "multiple exprs in body" do
    ms = fun do x ->
      x
      0
    end
    assert ms == [{:"$1", [], [:"$1", 0] }]
  end

  test "invalid fun args" do
    assert_raise ArgumentError, "invalid args to matchspec", fn ->
      delay_compile(fun 123)
    end
  end

  test "raise on invalid fun head" do
    assert_raise ArgumentError, "parameters to matchspec has to be a single var or tuple", fn ->
      delay_compile(fun do x, y -> 0 end)
    end

    assert_raise ArgumentError, "parameters to matchspec has to be a single var or tuple", fn ->
      delay_compile(fun do {x, y = z} -> 0 end)
    end

    assert_raise ArgumentError, "parameters to matchspec has to be a single var or tuple", fn ->
      delay_compile(fun do 123 -> 0 end)
    end
  end

  test "unbound var" do
    assert_raise ArgumentError, "variable `y` is unbound in matchspec", fn ->
      delay_compile(fun do x -> y end)
    end
  end

  test "invalid expression" do
    assert_raise ArgumentError, "illegal expression in matchspec", fn ->
      delay_compile(fun do x -> x = y end)
    end

    assert_raise ArgumentError, "illegal expression in matchspec", fn ->
      delay_compile(fun do x -> abc(x) end)
    end
  end
end
