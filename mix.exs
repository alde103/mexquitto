defmodule Mexquitto.MixProject do
  use Mix.Project

  def project do
    [
      app: :mexquitto,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tortoise, "~> 0.9"},
      {:muontrap, "~> 0.6.0"},
      {:x509, "~> 0.8"},
      {:certifi, "~> 2.5"},
    ]
  end
end
