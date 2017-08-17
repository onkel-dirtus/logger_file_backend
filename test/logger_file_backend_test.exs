defmodule LoggerFileBackendTest do
  use ExUnit.Case, async: false
  require Logger

  @backend {LoggerFileBackend, :test}

  import LoggerFileBackend, only: [prune: 1, metadata_matches?: 2]

  # add the backend here instead of `config/test.exs` due to issue 2649
  Logger.add_backend @backend

  setup do
    config [path: "test/logs/test.log", level: :debug]
    on_exit fn ->
      path() && File.rm_rf!(Path.dirname(path()))
    end
  end

  test "does not crash if path isn't set" do
    config path: nil

    Logger.debug "foo"
    assert {:error, :already_present} = Logger.add_backend(@backend)
  end

  test "can configure metadata_filter" do
    config metadata_filter: [md_key: true]
    Logger.debug("shouldn't", md_key: false)
    Logger.debug("should", md_key: true)
    refute log() =~ "shouldn't"
    assert log() =~ "should"
    config metadata_filter: nil
  end

  test "metadata_matches?" do
    assert metadata_matches?([a: 1], [a: 1]) == true # exact match
    assert metadata_matches?([b: 1], [a: 1]) == false # total mismatch
    assert metadata_matches?([b: 1], nil) == true # default to allow
    assert metadata_matches?([b: 1, a: 1], [a: 1]) == true # metadata is superset of filter
    assert metadata_matches?([c: 1, b: 1, a: 1], [b: 1, a: 1]) == true # multiple filter keys subset of metadata
    assert metadata_matches?([a: 1], [b: 1, a: 1]) == false # multiple filter keys superset of metadata
  end

  test "creates log file" do
    refute File.exists?(path())
    Logger.debug("this is a msg")
    assert File.exists?(path())
    assert log() =~ "this is a msg"
  end

  test "can log utf8 chars" do
    Logger.debug("ß\uFFaa\u0222")
    assert log() =~ "ßﾪȢ"
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
    assert log() =~ "hi�"
  end

  test "can configure format" do
    config format: "$message [$level]\n"

    Logger.debug("hello")
    assert log() =~ "hello [debug]"
  end

  test "can configure metadata" do
    config format: "$metadata$message\n", metadata: [:user_id, :auth]

    Logger.debug("hello")
    assert log() =~ "hello"

    Logger.metadata(auth: true)
    Logger.metadata(user_id: 11)
    Logger.metadata(user_id: 13)

    Logger.debug("hello")
    assert log() =~ "user_id=13 auth=true hello"
  end

  test "can configure level" do
    config level: :info

    Logger.debug("hello")
    refute File.exists?(path())
  end

  test "can configure path" do
    new_path = "test/logs/test.log.2"
    config path: new_path
    assert new_path == path()
  end

  test "logs to new file after old file has been moved" do
    config format: "$message\n"

    Logger.debug "foo"
    Logger.debug "bar"
    assert log() == "foo\nbar\n"

    {"", 0} = System.cmd("mv", [path(), path() <> ".1"])

    Logger.debug "biz"
    Logger.debug "baz"
    assert log() == "biz\nbaz\n"
  end

  test "closes old log file after log file has been moved" do
    Logger.debug "foo"
    assert has_open(path())

    new_path = path() <> ".1"
    {"", 0} = System.cmd("mv", [path(), new_path])

    assert has_open(new_path)

    Logger.debug "bar"

    assert has_open(path())
    refute has_open(new_path)
  end

  test "closes old log file after path has been changed" do
    Logger.debug "foo"
    assert has_open(path())

    org_path = path()
    config path: path() <> ".new"

    Logger.debug "bar"
    assert has_open(path())
    refute has_open(org_path)
  end

  test "log file rotate" do
    config format: "$message\n"
    config rotate: %{max_bytes: 4, keep: 4}

    Logger.debug "rotate1"
    Logger.debug "rotate2"
    Logger.debug "rotate3"
    Logger.debug "rotate4"
    Logger.debug "rotate5"
    Logger.debug "rotate6"


    p = path()

    assert File.read!("#{p}.4")  == "rotate2\n"
    assert File.read!("#{p}.3")  == "rotate3\n"
    assert File.read!("#{p}.2")  == "rotate4\n"
    assert File.read!("#{p}.1")  == "rotate5\n"
    assert File.read!(p)         == "rotate6\n"

    config rotate: nil
  end

  test "log file not rotate" do
    config format: "$message\n"
    config rotate: %{max_bytes: 100, keep: 4}

    words = ~w(rotate1 rotate2 rotate3 rotate4 rotate5 rotate6)
    words |> Enum.map(&(Logger.debug(&1)))

    assert log() == Enum.join(words, "\n") <> "\n"

    config rotate: nil

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
    {:ok, path} = :gen_event.call(Logger, @backend, :path)
    path
  end

  defp log do
    File.read!(path())
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end
end
