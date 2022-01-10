defmodule LoggerFileBackend.Mixfile do
  use Mix.Project

  @source_url "https://github.com/onkel-dirtus/logger_file_backend"
  @version "0.0.13"

  def project do
    [
      app: :logger_file_backend,
      version: @version,
      elixir: "~> 1.0",
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      description: "Simple logger backend that writes to a file",
      maintainers: ["Kurt Williams", "Everett Griffiths"],
      licenses: ["MIT"],
      files: [
        "lib",
        "assets/logo.png",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*"
      ],
      links: %{
        "Changelog" => "https://hexdocs.pm/logger_file_backend/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      logo: "assets/logo.png",
      formatters: ["html"]
    ]
  end
end
