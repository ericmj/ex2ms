defmodule Ex2ms.Mixfile do
  use Mix.Project

  @version "1.4.0"

  def project do
    [app: :ex2ms,
     version: @version,
     elixir: "~> 1.0",
     source_url: "https://github.com/ericmj",
     docs: [source_ref: "v#{@version}", extras: ["README.md"]],
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    []
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp description do
    """
    Translates Elixir functions to match specifications for use with `ets`.
    """
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md"],
     maintainers: ["Eric Meadows-Jönsson", "Martin Schurrer"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/ericmj/ex2ms"}]
  end
end
