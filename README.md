# ex2ms

[![Build Status](https://travis-ci.org/ericmj/ex2ms.svg?branch=master)](https://travis-ci.org/ericmj/ex2ms)

Translates Elixir functions to match specifications for use with `ets`.
Requires Elixir 1.0 or later.

## Usage

Add ex2ms to your Mix dependencies:

```elixir
defp deps do
  [{:ex2ms, "~> 1.0"}]
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

## License

    Copyright 2013 Eric Meadows-Jönsson

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
