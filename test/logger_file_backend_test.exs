defmodule LoggerFileBackendTest do
  use ExUnit.Case, async: false
  require Logger

  @backend {LoggerFileBackend, :test}

  # add the backend here instead of `config/test.exs` due to issue 2649
  Logger.add_backend @backend

  setup do
    config [path: "test/logs/test.log", level: :debug]
    on_exit fn ->
      path && File.rm_rf!(Path.dirname(path))
    end
  end

  test "does not crash if path isn't set" do
    config path: nil

    Logger.debug "foo"
    assert {:error, :already_present} = Logger.add_backend(@backend)
  end

  test "creates log file" do
    refute File.exists?(path)
    Logger.debug("this is a msg")
    assert File.exists?(path)
    assert log =~ "this is a msg"
  end

  test "can log utf8 chars" do
    Logger.debug("ß\x{0032}\x{0222}")
    assert log =~ "ß\x{0032}\x{0222}"
  end

  test "can configure format" do
    config format: "$message [$level]\n"

    Logger.debug("hello")
    assert log =~ "hello [debug]"
  end

  test "can configure metadata" do
    config format: "$metadata$message\n", metadata: [:user_id]

    Logger.debug("hello")
    assert log =~ "hello"

    Logger.metadata(user_id: 11)
    Logger.metadata(user_id: 13)

    Logger.debug("user_id=13 hello")
    assert log =~ "hello"
  end

  test "can configure level" do
    config level: :info

    Logger.debug("hello")
    refute File.exists?(path)
  end

  test "logs to file after old has been moved" do
    config format: "$message\n"

    Logger.debug "foo"
    Logger.debug "bar"
    assert log == "foo\nbar\n"

    {"", 0} = System.cmd("mv", [path, path <> ".1"])

    Logger.debug "biz"
    Logger.debug "baz"
    assert log == "biz\nbaz\n"
  end

  defp path do
    {:ok, path} = GenEvent.call(Logger, @backend, :path)
    path
  end

  defp log do
    File.read!(path)
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end
end
