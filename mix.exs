defmodule LoggerFileBackend.Mixfile do
  use Mix.Project

  def project do
    [app: :logger_file_backend,
     version: "0.0.11",
     elixir: "~> 1.0",
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    [applications: []]
  end

  defp description do
    "Simple logger backend that writes to a file"
  end

  defp package do
    [maintainers: ["Kurt Williams"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/onkel-dirtus/logger_file_backend"}]
  end

  defp deps do
    [{:credo, "~> 0.4", only: [:dev, :test]},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end
end
