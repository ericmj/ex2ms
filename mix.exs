defmodule Ex2ms.Mixfile do
  use Mix.Project

  @version "1.5.0"
  @github_url "https://github.com/ericmj/ex2ms"

  def project do
    [
      app: :ex2ms,
      version: @version,
      elixir: "~> 1.0",
      source_url: @github_url,
      docs: [source_ref: "v#{@version}", main: "readme", extras: ["README.md"]],
      description: description(),
      package: package(),
      deps: deps()
    ]
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
    [
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["Eric Meadows-Jönsson", "Martin Schurrer"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => @github_url}
    ]
  end
end
