# ex2ms

Translates Elixir pattern matches to match specifications for use with `ets`.

##### Examples
```elixir
iex(1)> import Ex2ms
iex(2)> fun do { x, y } = z when x > 10 -> z end
[{{:"$1",:"$2"},[{:>,:"$1",10}],[:"$_"]}]
iex(3)> :ets.test_ms({ 42, 43 }, v(2))
{:ok,{42,43}}
iex(4)> :ets.test_ms({ 0, 10 }, v(2))
{:ok,false}
```
