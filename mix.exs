defmodule Ex2ms.Mixfile do
  use Mix.Project

  def project do
    [ app: :ex2ms,
      version: "1.1.0",
      elixir: "~> 0.13.1 or ~> 0.14.0 or ~> 0.14.0-dev or ~> 0.15.0",
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
