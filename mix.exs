defmodule Memcache.MixProject do
  use Mix.Project

  def project do
    [
      package: package(),
      app: :memcached,
      version: "0.1.2",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp package do
    [
      description: "Memcache client for Elixir with support for pipelining",
      licenses: ["MIT"],
      maintainers: ["pguillory@gmail.com"],
      links: %{
        "GitHub" => "https://github.com/pguillory/elixir-memcache"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
