defmodule LoggerFileBackend.Mixfile do
  use Mix.Project

  def project do
    [app: :logger_file_backend,
     version: "0.0.3",
     elixir: "~> 1.0.0",
     description: description,
     package: package,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: []]
  end

  defp description do
    "Simple logger backend that writes to a file"
  end

  defp package do
    [contributors: ["Kurt Williams"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/onkel-dirtus/logger_file_backend"}]
  end

  defp deps do
    []
  end
end
