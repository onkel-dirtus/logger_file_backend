defmodule LoggerFileBackendTest.MockTime do
  use Agent

  ### Using 2 agents now to separate the use cases of m_times and system times
  # :time_pin pins the current time
  # :m_time_playlist stores a queue of replayable m_times

  def start_link do
    Agent.start_link(fn -> %{pinned: false, time: nil} end, name: :time_pin)
    Agent.start_link(fn -> %{} end, name: :m_time_playlist)
  end

  def get_time do
    case read_agent(:time_pin) do
      %{ pinned: false } ->
        NaiveDateTime.local_now()
      %{ pinned: true, time: time } ->
        time
    end
  end

  def pin_time(time) do
    write_agent(:time_pin, fn _state -> %{pinned: true, time: time} end)
  end

  def unpin_time do
    write_agent(:time_pin, fn _state -> %{pinned: false, time: nil} end)
  end

  defp read_file_time(path) do
    {:ok, {:file_info, _, _, _, _, real_m_time, _, _, _, _, _, _, _, _}} = :file.read_file_info(path, [:raw])
    NaiveDateTime.from_erl!(real_m_time)
  end

  def set_m_time(path, time) do
    case read_agent(:m_time_playlist) do

      state ->
        case Map.has_key?(state, path) do
          true ->
            write_agent(:m_time_playlist, fn _state -> Map.put(state, path, :queue.in(time, Map.get(state, path))) end)
          false ->
            write_agent(:m_time_playlist, fn _state -> Map.put(state, path, :queue.in(time, :queue.new())) end)
        end

    end
  end

  def get_m_time(path) do
    case read_agent(:m_time_playlist) do
      state ->
        case Map.get(state, path) do
          {:error, :enoent} ->
            read_file_time(path)
          nil ->
            read_file_time(path)
          queue ->
            {{:value, time}, new_queue} = :queue.out(queue)
            write_agent(:m_time_playlist, fn _state -> Map.put(state, path, new_queue) end)
            time
        end
    end
  end

  def debug_agent do
    case read_agent(:time_pin) do
      state -> IO.inspect(state)
    end
    case read_agent(:m_time_playlist) do
      state -> IO.inspect(state)
    end
  end

  defp write_agent(name, fun) do
    Agent.update(name, fun)
  end

  defp read_agent(name) when is_atom(name) do
    Agent.get(name, fn state -> state end)
  end

end
