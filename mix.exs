defmodule Ex2ms.Mixfile do
  use Mix.Project

  def project do
    [ app: :ex2ms,
      version: "1.3.0",
      elixir: "~> 1.0.0-rc1 or ~> 1.0.0",
      description: description,
      package: package,
      deps: [] ]
  end

  def application do
    []
  end

  defp description do
    """
    Translates Elixir functions to match specifications for use with `ets`.
    """
  end

  defp package do
    [ files: ["lib", "mix.exs", "README.md"],
      contributors: ["Eric Meadows-Jönsson", "Martin Schurrer"],
      licenses: ["Apache 2.0"],
      links: %{ "GitHub" => "https://github.com/ericmj/ex2ms" } ]
  end
end
