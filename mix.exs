defmodule LoggerFileBackend.Mixfile do
  use Mix.Project

  @version "0.0.12"

  def project do
    [
      app: :logger_file_backend,
      version: @version,
      elixir: "~> 1.0",
      description: description(),
      package: package(),
      deps: deps(),
      docs: [
        main: "readme",
        source_ref: "v#{@version}",
        source_url: "https://github.com/onkel-dirtus/logger_file_backend",
        logo: "assets/logo.png",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp description do
    "Simple logger backend that writes to a file"
  end

  defp package do
    [
      maintainers: ["Kurt Williams", "Everett Griffiths"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/onkel-dirtus/logger_file_backend"},
      files: [
        "lib",
        "assets/logo.png",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*"
      ]
    ]
  end

  defp deps do
    [{:credo, "~> 1.0", only: [:dev, :test]}, {:ex_doc, "~> 0.24", only: :dev}]
  end
end
