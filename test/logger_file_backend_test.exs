defmodule LoggerFileBackendTest do
  use ExUnit.Case, async: false
  require Logger

  @backend {LoggerFileBackend, :test}

  import LoggerFileBackend, only: [prune: 1]

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

  test "prune/1" do
    assert prune(1) == "�"
    assert prune(<<"hí", 233>>) == "hí�"
    assert prune(["hi"|233]) == ["hi"|"�"]
    assert prune([233|"hi"]) == [233|"hi"]
    assert prune([[]|[]]) == [[]]
  end

  test "prunes invalid utf-8 codepoints" do
    Logger.debug(<<"hi", 233>>)
    assert log =~ "hi�"
  end

  test "can configure format" do
    config format: "$message [$level]\n"

    Logger.debug("hello")
    assert log =~ "hello [debug]"
  end

  test "can configure metadata" do
    config format: "$metadata$message\n", metadata: [:user_id, :auth]

    Logger.debug("hello")
    assert log =~ "hello"

    Logger.metadata(auth: true)
    Logger.metadata(user_id: 11)
    Logger.metadata(user_id: 13)

    Logger.debug("hello")
    assert log =~ "user_id=13 auth=true hello"
  end

  test "can configure level" do
    config level: :info

    Logger.debug("hello")
    refute File.exists?(path)
  end

  test "can configure path" do
    new_path = "test/logs/test.log.2"
    config path: new_path
    assert new_path == path
  end

  test "logs to new file after old file has been moved" do
    config format: "$message\n"

    Logger.debug "foo"
    Logger.debug "bar"
    assert log == "foo\nbar\n"

    {"", 0} = System.cmd("mv", [path, path <> ".1"])

    Logger.debug "biz"
    Logger.debug "baz"
    assert log == "biz\nbaz\n"
  end

  test "closes old log file after log file has been moved" do
    Logger.debug "foo"
    assert has_open(path)

    new_path = path <> ".1"
    {"", 0} = System.cmd("mv", [path, new_path])

    assert has_open(new_path)

    Logger.debug "bar"

    assert has_open(path)
    refute has_open(new_path)
  end

  test "closes old log file after path has been changed" do
    Logger.debug "foo"
    assert has_open(path)

    org_path = path
    config path: path <> ".new"

    Logger.debug "bar"
    assert has_open(path)
    refute has_open(org_path)
  end

  defp has_open(path) do
    has_open(:os.type, path)
  end

  defp has_open({:unix,_}, path) do
    case System.cmd("lsof", [path]) do
      {output, 0} ->
        output =~ System.get_pid
      _ -> false
    end
  end

  defp has_open(_, _) do
    false
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
