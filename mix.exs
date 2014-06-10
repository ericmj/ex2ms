defmodule Ex2ms.Mixfile do
  use Mix.Project

  def project do
    [ app: :ex2ms,
      version: "0.1.1-dev",
      elixir: "~> 0.13.1 or ~> 0.14.0 or ~> 0.14.0-dev",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    []
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    []
  end
end
