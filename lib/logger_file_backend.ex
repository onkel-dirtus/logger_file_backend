defmodule LoggerFileBackend do
  use GenEvent

  alias LoggerFileBackendUtil, as: Util

  @type path      :: String.t
  @type file      :: :file.io_device
  @type inode     :: File.Stat.t
  @type format    :: String.t
  @type level     :: Logger.level
  @type metadata  :: [atom]


  @default_format "$time $metadata[$level] $message\n"
  @default_rotate_size 10485760 # 10MB
  @default_rotate_count 10
  @default_check_interval 600_000 # 10 minutes

  def init({__MODULE__, name}) do
    configs = configure(name, [])
    schedule_rotation(name)
    {:ok, configs}
  end


  def handle_call({:configure, opts}, %{name: name}) do
    configs = configure(name, opts)
    schedule_rotation(name)
    {:ok, :ok, configs}
  end


  def handle_call(:path, %{path: path} = state) do
    {:ok, {:ok, path}, state}
  end


  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    else
      {:ok, state}
    end
  end

  def handle_info({:rotate, path}, %{path: path, count: count} = state) do
    Util.rotate_logfile(path, count)
    schedule_rotation(path)
    {:ok, state}
  end

  def handle_info(_info, state) do
    {:ok, state}
  end


  # helpers

  defp log_event(_level, _msg, _ts, _md, %{path: nil} = state) do
    {:ok, state}
  end


  defp log_event(level, msg, ts, md, %{path: path, io_device: nil} = state) when is_binary(path) do
    case Util.ensure_logfile(path, nil, nil) do
      {:ok, io_device, inode, _} ->
        do_write(level, msg, ts, md, %{state | io_device: io_device, inode: inode})
      _ ->
        {:ok, state}
    end
  end

  defp log_event(level, msg, {date, {h, m, s, ms}} = ts, md, %{path: path, io_device: io_device, inode: inode, size: rotate_size, count: count} = state) when is_binary(path) do
    from = :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})
    tss = case :calendar.local_time_to_universal_time_dst({date, {h, m, s}}) do
      [] -> raise "local_time_to_universal_time_dst error"
      [_dst, utc] -> utc
      [utc] -> utc
    end |> :calendar.datetime_to_gregorian_seconds
    tss = (tss - from) * 1000 + ms
    y1 = rem tss, 1000_000_000
    tss = {div(tss, 1000_000_000), div(y1, 1000), rem(y1, 1000) * 1000}
    last_check = div :timer.now_diff(tss, state.last_check), 1000
    case last_check >= state.check_interval or io_device == nil or Util.file_changed?(path, inode) do
      true ->
        case Util.ensure_logfile(path, io_device, inode) do
          {:ok, _, _, size} when rotate_size != 0 and size > rotate_size ->
            case Util.rotate_logfile(path, count) do
              :ok -> log_event(level, msg, ts, md, state)
              _ -> {:ok, state}
            end
          {:ok, new_io_device, new_inode, _} ->
            do_write(level, msg, ts, md, %{state | last_check: tss, io_device: new_io_device, inode: new_inode})
          _ ->
            {:ok, state}
        end
      false ->
        do_write(level, msg, ts, md, state)
    end
  end


  defp do_write(level, msg, ts, md, %{io_device: io_device} = state) do
    :file.write(io_device, format_event(level, msg, ts, md, state))
    {:ok, state}
  end


  defp format_event(level, msg, ts, md, %{format: format, metadata: metadata}) do
    Logger.Formatter.format(format, level, msg, ts, Dict.take(md, metadata))
  end


  defp configure(name, opts) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level    = Keyword.get(opts, :level)
    metadata = Keyword.get(opts, :metadata, [])
    format   = Keyword.get(opts, :format, @default_format) |> Logger.Formatter.compile
    path     = Keyword.get(opts, :path)
    size     = Keyword.get(opts, :size, @default_rotate_size)
    count    = Keyword.get(opts, :count, @default_rotate_count)
    check_interval = Keyword.get(opts, :check_interval, @default_check_interval)

    %{name: name,
      path: path,
      io_device: nil,
      inode: nil,
      format: format,
      level: level,
      metadata: metadata,
      size: size,
      count: count,
      check_interval: check_interval,
      last_check: :os.timestamp
    }
  end

  # schedule 1 day at midnight
  defp schedule_rotation(name) do
    {ms, s, _} = :os.timestamp
    now_ts = ms * 1000000 + s
    tomorrow_ts = now_ts + 86400
    {tomorrow, _} = {div(tomorrow_ts, 1000_000), rem(tomorrow_ts, 1000_000), 0} |> :calendar.now_to_local_time
    {days, {h, m, s}} = :calendar.time_difference(:calendar.local_time, {tomorrow, {0,0,0}})
    next_time = days * 86400 + h * 3600 + m * 60 + s
    :erlang.send_after(next_time, self, {:rotate, name})
    :ok
  end
end
