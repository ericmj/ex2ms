# ex2ms

Translates Elixir functions to match specifications for use with `ets`.
Requires Elixir 0.9.4-dev or later.

#### Usage
Add ex2ms to your Mix dependencies:
```elixir
defp deps do
  [{ :ex2ms, github: "ericmj/ex2ms" }]
end
```

In your shell write the following to get up and running to try ex2ms out:
```bash
mix deps.get
iex -S mix
```
```elixir
iex(1)> import Ex2ms
iex(2)> fun do { x, y } = z when x > 10 -> z end
[{{:"$1",:"$2"},[{:>,:"$1",10}],[:"$_"]}]
iex(3)> :ets.test_ms({ 42, 43 }, v(2))
{:ok,{42,43}}
iex(4)> :ets.test_ms({ 0, 10 }, v(2))
{:ok,false}
```

