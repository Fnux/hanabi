defmodule Hanabi.Mixfile do
  use Mix.Project

  def project do
    [app: :hanabi,
     version: "0.1.1",
     elixir: "~> 1.4",
     description: description(),
     package: package(),
     docs: [main: "readme", extras: ["README.md"]],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     name: "Hanabi",
     source_url: "https://github.com/fnux/hanabi"]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [mod: {Hanabi, []}, extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:exirc, "~> 1.0.1", only: :test, runtime: false}
    ]
  end

  defp description do
    """
    Simple IRC server designed to build bridges.
    """
  end

  defp package do
    [
      name: :hanabi,
      files: ["lib", "mix.exs", "README.md", "LICENSE.txt"],
      maintainers: ["Timothée Floure"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/fnux/hanabi"}
    ]
  end
end
