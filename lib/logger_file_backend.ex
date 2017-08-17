defmodule LoggerFileBackend do
  @moduledoc"""
  """

  @behaviour :gen_event


  @type path      :: String.t
  @type file      :: :file.io_device
  @type inode     :: File.Stat.t
  @type format    :: String.t
  @type level     :: Logger.level
  @type metadata  :: [atom]


  @default_format "$time $metadata[$level] $message\n"

  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end


  def handle_call({:configure, opts}, %{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end


  def handle_call(:path, %{path: path} = state) do
    {:ok, {:ok, path}, state}
  end


  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level, metadata_filter: metadata_filter} = state) do
    if (is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt) and metadata_matches?(md, metadata_filter) do
      log_event(level, msg, ts, md, state)
    else
      {:ok, state}
    end
  end

  def handle_event(:flush, state) do
    # We're not buffering anything so this is a no-op
    {:ok, state}
  end


  # helpers

  defp log_event(_level, _msg, _ts, _md, %{path: nil} = state) do
    {:ok, state}
  end

  defp log_event(level, msg, ts, md, %{path: path, io_device: nil} = state) when is_binary(path) do
    case open_log(path) do
      {:ok, io_device, inode} ->
        log_event(level, msg, ts, md, %{state | io_device: io_device, inode: inode})
      _other ->
        {:ok, state}
    end
  end

  defp log_event(level, msg, ts, md, %{path: path, io_device: io_device, inode: inode, rotate: rotate} = state) when is_binary(path) do
    if !is_nil(inode) and inode == get_inode(path) and rotate(path, rotate) do
      output = format_event(level, msg, ts, md, state)
      try do
        IO.write(io_device, output)
        {:ok, state}
      rescue
        ErlangError ->
          case open_log(path) do
            {:ok, io_device, inode} ->
              IO.write(io_device, prune(output))
              {:ok, %{state | io_device: io_device, inode: inode}}
            _other ->
              {:ok, %{state | io_device: nil, inode: nil}}
          end
      end
    else
      File.close(io_device)
      log_event(level, msg, ts, md, %{state | io_device: nil, inode: nil})
    end
  end

  defp rename_file(path, keep) do

    File.rm("#{path}.#{keep}")

    Enum.map(keep-1..1, fn(x) -> File.rename("#{path}.#{x}", "#{path}.#{x+1}") end)

    case File.rename(path, "#{path}.1") do
      :ok -> false
      _   -> true
    end

  end

  defp rotate(path, %{max_bytes: max_bytes, keep: keep }) when is_integer(max_bytes) and is_integer(keep) and keep > 0 do

    case File.stat(path) do
      {:ok, %{size: size}} -> if size >= max_bytes, do:  rename_file(path, keep) , else: true
      _                    -> true
    end

  end

  defp rotate(_path, nil), do: true



  defp open_log(path) do
    case (path |> Path.dirname |> File.mkdir_p) do
      :ok ->
        case File.open(path, [:append, :utf8]) do
          {:ok, io_device} -> {:ok, io_device, get_inode(path)}
          other -> other
        end
      other -> other
    end
  end


  defp format_event(level, msg, ts, md, %{format: format, metadata: keys}) do
    Logger.Formatter.format(format, level, msg, ts, take_metadata(md, keys))
  end

  @doc false
  @spec metadata_matches?(Keyword.t, nil|Keyword.t) :: true|false
  def metadata_matches?(_md, nil), do: true
  def metadata_matches?(_md, []), do: true # all of the filter keys are present
  def metadata_matches?(md, [{key, val}|rest]) do
    case Keyword.fetch(md, key) do
      {:ok, ^val} ->
        metadata_matches?(md, rest)
      _ -> false #fail on first mismatch
    end
  end



  defp take_metadata(metadata, keys) do
    metadatas = Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error     -> acc
      end
    end)

    Enum.reverse(metadatas)
  end


  defp get_inode(path) do
    case File.stat(path) do
      {:ok, %File.Stat{inode: inode}} -> inode
      {:error, _} -> nil
    end
  end


  defp configure(name, opts) do
    state = %{name: nil, path: nil, io_device: nil, inode: nil, format: nil, level: nil, metadata: nil, metadata_filter: nil, rotate: nil}
    configure(name, opts, state)
  end

  defp configure(name, opts, state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level           = Keyword.get(opts, :level)
    metadata        = Keyword.get(opts, :metadata, [])
    format_opts     = Keyword.get(opts, :format, @default_format)
    format          = Logger.Formatter.compile(format_opts)
    path            = Keyword.get(opts, :path)
    metadata_filter = Keyword.get(opts, :metadata_filter)
    rotate          = Keyword.get(opts, :rotate)

    %{state | name: name, path: path, format: format, level: level, metadata: metadata, metadata_filter: metadata_filter, rotate: rotate}
  end

  @replacement "�"

  @spec prune(IO.chardata) :: IO.chardata
  def prune(binary) when is_binary(binary), do: prune_binary(binary, "")
  def prune([h|t]) when h in 0..1114111, do: [h|prune(t)]
  def prune([h|t]), do: [prune(h)|prune(t)]
  def prune([]), do: []
  def prune(_), do: @replacement

  defp prune_binary(<<h::utf8, t::binary>>, acc),
    do: prune_binary(t, <<acc::binary, h::utf8>>)
  defp prune_binary(<<_, t::binary>>, acc),
    do: prune_binary(t, <<acc::binary, @replacement>>)
  defp prune_binary(<<>>, acc),
    do: acc
end
