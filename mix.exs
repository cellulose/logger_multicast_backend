defmodule LoggerMulticastBackend.Mixfile do

  use Mix.Project

  @version "0.3.0"

  def project, do: [
    app: :logger_multicast_backend,
    version: @version,
    elixir: "~> 1.0",
    description: description(),
    package: package(),
    deps: deps(),
    docs: [
            source_ref: "v#{@version}", main: "LoggerMulticastBackend",
            source_url: "https://github.com/cellulose/logger_multicast_backend",
            extras: [ "README.md", "CHANGELOG.md"]
          ]
  ]

  defp description, do: "Elixir Logger backend using Multicast UDP"

  defp package, do: [
    contributors: ["Garth Hitchens", "Chris Dutton"],
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/cellulose/logger_multicast_backend"},
    files: ~w(lib config) ++ ~w(README.md CHANGELOG.md LICENSE mix.exs)
  ]

  def application, do: [ applications: [:gen_stage, :logger] ]

  defp deps, do: [
    {:ex_doc, "~> 0.7", only: :dev},
    {:gen_stage, "~> 0.4"}
  ]
end
