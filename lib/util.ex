defmodule LoggerFileBackendUtil do
  
  def rotate_logfile(file, 0), do: File.rm_rf(file)
  def rotate_logfile(file, 1) do
    case :file.rename(file, "#{file}.0") do
      :ok -> :ok
      _ -> rotate_logfile(file, 0)
    end
  end
  def rotate_logfile(file, count) do
    :file.rename("#{file}.#{count - 2}", "#{file}.#{count - 1}")
    rotate_logfile(file, count - 1)
  end

  def open_logfile(path) do
    case (path |> Path.dirname |> File.mkdir_p) do
      :ok ->
        case File.open(path, [:append, :raw]) do
          {:ok, io_device} ->
            [inode, size] = file_info(path)
            {:ok, io_device, inode, size}
          other -> other
        end
      other -> other
    end
  end

  def ensure_logfile(path, io_device, inode) do
    case File.stat(path) do
      {:ok, %File.Stat{inode: inode2, size: size2}} ->
        case inode == inode2 do
          true ->
            {:ok, io_device, inode, size2}
          false ->
            File.close io_device
            case open_logfile(path) do
              {:ok, io_device2, inode3, size3} ->
                {:ok, io_device2, inode3, size3}
              err ->
                err
            end
        end
      _ ->
        File.close io_device
        case open_logfile(path) do
          {:ok, io_device, inode, size} ->
            {:ok, io_device, inode, size}
          err -> err
        end
    end
  end

  def file_changed?(path, inode) do
    [new_inode, _] = file_info(path)
    new_inode != inode
  end

  defp file_info(path) do
    case File.stat(path) do
      {:ok, %File.Stat{inode: inode, size: size}} ->
        [inode, size]
      {:error, _} ->
        [nil, nil]
    end
  end
end
