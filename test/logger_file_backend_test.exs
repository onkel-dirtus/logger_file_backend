defmodule LoggerFileBackendTest do
  use ExUnit.Case, async: false
  require Logger

  @moduletag :tmp_dir
  @moduletag capture_log: true

  import LoggerFileBackend, only: [prune: 1, metadata_matches?: 2]

  setup context do
    backend = {LoggerFileBackend, context.test}
    # We add and remove the backend here to avoid cross-test effects
    Logger.add_backend(backend, flush: true)

    config(Map.put(context, :backend, backend), path: logfile(context), level: :debug)

    on_exit(fn ->
      :ok = Logger.remove_backend(backend)
    end)

    {:ok, [backend: backend]}
  end

  test "does not crash if path isn't set", %{backend: backend} = context do
    config(context, path: nil)

    Logger.debug("foo")
    assert {:error, :already_present} = Logger.add_backend(backend)
  end

  test "can configure metadata_filter", context do
    config(context, metadata_filter: [md_key: true])
    Logger.debug("shouldn't", md_key: false)
    Logger.debug("should", md_key: true)
    refute log(context) =~ "shouldn't"
    assert log(context) =~ "should"
    config(context, metadata_filter: nil)
  end

  test "can configure metadata_reject", context do
    config(context, metadata_reject: [md_key: false])
    Logger.debug("shouldn't", md_key: false)
    Logger.debug("should", md_key: true)
    refute log(context) =~ "shouldn't"
    assert log(context) =~ "should"
    config(context, metadata_reject: nil)
  end

  test "metadata_matches?" do
    # exact match
    assert metadata_matches?([a: 1], a: 1) == true
    # included in array match
    assert metadata_matches?([a: 1], a: [1, 2]) == true
    # total mismatch
    assert metadata_matches?([b: 1], a: 1) == false
    # default to allow
    assert metadata_matches?([b: 1], nil) == true
    # metadata is superset of filter
    assert metadata_matches?([b: 1, a: 1], a: 1) == true
    # multiple filter keys subset of metadata
    assert metadata_matches?([c: 1, b: 1, a: 1], b: 1, a: 1) == true
    # multiple filter keys superset of metadata
    assert metadata_matches?([a: 1], b: 1, a: 1) == false
  end

  test "creates log file", context do
    refute File.exists?(path(context))
    Logger.debug("this is a msg")
    assert File.exists?(path(context))
    assert log(context) =~ "this is a msg"
  end

  test "can log utf8 chars", context do
    Logger.debug("ß\uFFaa\u0222")
    assert log(context) =~ "ßﾪȢ"
  end

  test "prune/1" do
    assert prune(1) == "�"
    assert prune(<<"hí", 233>>) == "hí�"
    assert prune(["hi" | 233]) == ["hi" | "�"]
    assert prune([233 | "hi"]) == [233 | "hi"]
    assert prune([[] | []]) == [[]]
  end

  test "prunes invalid utf-8 codepoints", context do
    Logger.debug(<<"hi", 233>>)
    assert log(context) =~ "hi�"
  end

  test "can configure format", context do
    config(context, format: "$message [$level]\n")

    Logger.debug("hello")
    assert log(context) =~ "hello [debug]"
  end

  test "can configure custom formatter", context do
    formatter = LoggerJSON.Formatters.Basic.new(metadata: [:domain, :erl_level, :module])
    config(context, formatter: formatter)

    Logger.debug("hello")

    assert log(context) =~
             ~r/{"message":"hello","metadata":{"domain":\["elixir"\],"erl_level":"debug","module":"Elixir\.LoggerFileBackendTest"},"severity":"debug","time":"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z"}\n/
  end

  test "can configure metadata", context do
    config(context, format: "$metadata$message\n", metadata: [:user_id, :auth])

    Logger.debug("hello")
    assert log(context) =~ "hello"

    Logger.metadata(auth: true)
    Logger.metadata(user_id: 11)
    Logger.metadata(user_id: 13)

    Logger.debug("hello")
    assert log(context) =~ "user_id=13 auth=true hello"
  end

  test "can configure level", context do
    config(context, level: :info)

    Logger.debug("hello")
    refute File.exists?(path(context))
  end

  test "can configure path", context do
    new_path = "test/logs/test.log.2"
    config(context, path: new_path)
    assert new_path == path(context)
  end

  test "logs to new file after old file has been moved", context do
    config(context, format: "$message\n")

    Logger.debug("foo")
    Logger.debug("bar")
    assert log(context) == "foo\nbar\n"

    {"", 0} = System.cmd("mv", [path(context), path(context) <> ".1"])

    Logger.debug("biz")
    Logger.debug("baz")
    assert log(context) == "biz\nbaz\n"
  end

  test "closes old log file after log file has been moved", context do
    Logger.debug("foo")
    assert has_open(path(context))

    new_path = path(context) <> ".1"
    {"", 0} = System.cmd("mv", [path(context), new_path])

    assert has_open(new_path)

    Logger.debug("bar")

    assert has_open(path(context))
    refute has_open(new_path)
  end

  test "closes old log file after path has been changed", context do
    Logger.debug("foo")
    assert has_open(path(context))

    org_path = path(context)
    config(context, path: path(context) <> ".new")

    Logger.debug("bar")
    assert has_open(path(context))
    refute has_open(org_path)
  end

  test "log file rotate", context do
    config(context, format: "$message\n")
    config(context, rotate: %{max_bytes: 4, keep: 4})

    Logger.debug("rotate1")
    Logger.debug("rotate2")
    Logger.debug("rotate3")
    Logger.debug("rotate4")
    Logger.debug("rotate5")
    Logger.debug("rotate6")

    p = path(context)

    assert File.read!("#{p}.4") == "rotate2\n"
    assert File.read!("#{p}.3") == "rotate3\n"
    assert File.read!("#{p}.2") == "rotate4\n"
    assert File.read!("#{p}.1") == "rotate5\n"
    assert File.read!(p) == "rotate6\n"

    config(context, rotate: nil)
  end

  test "log file not rotate", context do
    config(context, format: "$message\n")
    config(context, rotate: %{max_bytes: 100, keep: 4})

    words = ~w(rotate1 rotate2 rotate3 rotate4 rotate5 rotate6)
    words |> Enum.map(&Logger.debug(&1))

    assert log(context) == Enum.join(words, "\n") <> "\n"

    config(context, rotate: nil)
  end

  test "Allow :all to metadata", context do
    config(context, format: "$metadata")

    config(context, metadata: [])
    Logger.debug("metadata", metadata1: "foo", metadata2: "bar")
    assert log(context) == ""

    config(context, metadata: [:metadata3])
    Logger.debug("metadata", metadata3: "foo", metadata4: "bar")
    assert log(context) == "metadata3=foo "

    config(context, metadata: :all)
    Logger.debug("metadata", metadata5: "foo", metadata6: "bar")

    # Match separately for metadata5/metadata6 to avoid depending on order
    contents = log(context)
    assert contents =~ "metadata5=foo"
    assert contents =~ "metadata6=bar"
  end

  defp has_open(path) do
    has_open(:os.type(), path)
  end

  defp has_open({:unix, _}, path) do
    case System.cmd("lsof", ["-w", path]) do
      {output, 0} ->
        output =~ System.pid()

      _ ->
        false
    end
  end

  defp has_open(_, _) do
    false
  end

  defp path(%{backend: backend}) do
    {:ok, path} = :gen_event.call(Logger, backend, :path)
    path
  end

  defp log(context) do
    File.read!(path(context))
  end

  defp config(%{backend: backend}, opts) do
    :ok = Logger.configure_backend(backend, opts)
  end

  defp logfile(%{tmp_dir: basedir, test: test_name}) do
    logfile =
      test_name
      |> Atom.to_string()
      |> String.replace(" ", "_")

    Path.join(basedir, logfile)
  end
end
