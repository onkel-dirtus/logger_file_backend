defmodule LoggerFileBackendTest do
  use ExUnit.Case, async: false
  alias LoggerFileBackendTest.MockTime
  require Logger

  @backend {LoggerFileBackend, :test}
  @basedir "test/logs"

  import LoggerFileBackend, only: [prune: 1, metadata_matches?: 2]

  setup_all do
    on_exit(fn ->
      File.rm_rf!(@basedir)
    end)
  end

  setup context do
    # We add and remove the backend here to avoid cross-test effects
    Logger.add_backend(@backend, flush: true)

    config(path: logfile(context, @basedir), level: :debug)

    on_exit(fn ->
      :ok = Logger.remove_backend(@backend)
    end)
  end

  test "does not crash if path isn't set" do
    config(path: nil)

    Logger.debug("foo")
    assert {:error, :already_present} = Logger.add_backend(@backend)
  end

  test "can configure metadata_filter" do
    config(metadata_filter: [md_key: true])
    Logger.debug("shouldn't", md_key: false)
    Logger.debug("should", md_key: true)
    refute log() =~ "shouldn't"
    assert log() =~ "should"
    config(metadata_filter: nil)
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
    assert prune(["hi" | 233]) == ["hi" | "�"]
    assert prune([233 | "hi"]) == [233 | "hi"]
    assert prune([[] | []]) == [[]]
  end

  test "prunes invalid utf-8 codepoints" do
    Logger.debug(<<"hi", 233>>)
    assert log() =~ "hi�"
  end

  test "can configure format" do
    config(format: "$message [$level]\n")

    Logger.debug("hello")
    assert log() =~ "hello [debug]"
  end

  test "can configure metadata" do
    config(format: "$metadata$message\n", metadata: [:user_id, :auth])

    Logger.debug("hello")
    assert log() =~ "hello"

    Logger.metadata(auth: true)
    Logger.metadata(user_id: 11)
    Logger.metadata(user_id: 13)

    Logger.debug("hello")
    assert log() =~ "user_id=13 auth=true hello"
  end

  test "can configure level" do
    config(level: :info)

    Logger.debug("hello")
    refute File.exists?(path())
  end

  test "can configure path" do
    new_path = "test/logs/test.log.2"
    config(path: new_path)
    assert new_path == path()
  end

  test "logs to new file after old file has been moved" do
    config(format: "$message\n")

    Logger.debug("foo")
    Logger.debug("bar")
    assert log() == "foo\nbar\n"

    {"", 0} = System.cmd("mv", [path(), path() <> ".1"])

    Logger.debug("biz")
    Logger.debug("baz")
    assert log() == "biz\nbaz\n"
  end

  test "closes old log file after log file has been moved" do
    Logger.debug("foo")
    assert has_open(path())

    new_path = path() <> ".1"
    {"", 0} = System.cmd("mv", [path(), new_path])

    assert has_open(new_path)

    Logger.debug("bar")

    assert has_open(path())
    refute has_open(new_path)
  end

  test "closes old log file after path has been changed" do
    Logger.debug("foo")
    assert has_open(path())

    org_path = path()
    config(path: path() <> ".new")

    Logger.debug("bar")
    assert has_open(path())
    refute has_open(org_path)
  end

  test "log file rotate" do
    config(format: "$message\n")
    config(rotate: %{max_bytes: 4, keep: 4})

    Logger.debug("rotate1")
    Logger.debug("rotate2")
    Logger.debug("rotate3")
    Logger.debug("rotate4")
    Logger.debug("rotate5")
    Logger.debug("rotate6")

    p = path()

    assert File.read!("#{p}.4") == "rotate2\n"
    assert File.read!("#{p}.3") == "rotate3\n"
    assert File.read!("#{p}.2") == "rotate4\n"
    assert File.read!("#{p}.1") == "rotate5\n"
    assert File.read!(p) == "rotate6\n"

    config(rotate: nil)
  end

  test "log file rotates on new days" do
    config(format: "$message\n")
    config(rotate: %{period: :daily, keep: 4})
    config(time_adapter: LoggerFileBackendTest.MockTime)

    p = path()

    time  = ~N[2000-01-01 12:13:04]
    time2 = ~N[2000-01-02 12:13:04]
    time3 = ~N[2000-01-03 12:13:04]
    time4 = ~N[2000-01-04 12:13:04]
    time5 = ~N[2000-01-05 12:13:04]
    time6 = ~N[2000-01-06 12:13:04]

    MockTime.pin_time(time)
    MockTime.set_m_time(p, time)   # initial log write
    debug("rotate1")

    MockTime.pin_time(time2)
    MockTime.set_m_time(p, time)   # second log write - triggers rollover
    MockTime.set_m_time(p, time2)  # log file 2 m_time
    debug("rotate2")

    MockTime.pin_time(time3)
    MockTime.set_m_time(p, time2)
    MockTime.set_m_time(p, time3)
    debug("rotate3")

    MockTime.pin_time(time4)
    MockTime.set_m_time(p, time3)
    MockTime.set_m_time(p, time4)
    debug("rotate4")

    MockTime.pin_time(time5)
    MockTime.set_m_time(p, time4)
    MockTime.set_m_time(p, time5)
    debug("rotate5")

    MockTime.pin_time(time6)
    MockTime.set_m_time(p, time5)
    MockTime.set_m_time(p, time6)
    debug("rotate6")

    assert File.read!("#{p}.20000102") == "rotate2\n"
    assert File.read!("#{p}.20000103") == "rotate3\n"
    assert File.read!("#{p}.20000104") == "rotate4\n"
    assert File.read!("#{p}.20000105") == "rotate5\n"
    assert File.read!(p) == "rotate6\n"

    config(rotate: nil)
    config(timeadapter: LoggerFileBackend.Time)
  end

  test "log file not rotate" do
    config(format: "$message\n")
    config(rotate: %{max_bytes: 100, keep: 4})

    words = ~w(rotate1 rotate2 rotate3 rotate4 rotate5 rotate6)
    words |> Enum.map(&Logger.debug(&1))

    assert log() == Enum.join(words, "\n") <> "\n"

    config(rotate: nil)
  end

  test "Allow :all to metadata" do
    config(format: "$metadata")

    config(metadata: [])
    Logger.debug("metadata", metadata1: "foo", metadata2: "bar")
    assert log() == ""

    config(metadata: [:metadata3])
    Logger.debug("metadata", metadata3: "foo", metadata4: "bar")
    assert log() == "metadata3=foo "

    config(metadata: :all)
    Logger.debug("metadata", metadata5: "foo", metadata6: "bar")

    # Match separately for metadata5/metadata6 to avoid depending on order
    contents = log()
    assert contents =~ "metadata5=foo"
    assert contents =~ "metadata6=bar"
  end

  defp has_open(path) do
    has_open(:os.type(), path)
  end

  defp has_open({:unix, _}, path) do
    case System.cmd("lsof", [path]) do
      {output, 0} ->
        output =~ System.get_pid()

      _ ->
        false
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
    :ok = Logger.configure_backend(@backend, opts)
  end

  defp logfile(context, basedir) do
    logfile =
      context.test
      |> Atom.to_string()
      |> String.replace(" ", "_")

    Path.join(basedir, logfile)
  end

  defp debug(message) do
    log = {:debug, nil, {Logger, message, :calendar.local_time(), []}}
    :ok = :gen_event.call(Logger, @backend, {:log_for_test, log})
  end

end
