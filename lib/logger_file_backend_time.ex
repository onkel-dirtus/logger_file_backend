defmodule LoggerFileBackend.Time do

  def get_time do
    NaiveDateTime.local_now()
  end

  def get_m_time(path) do
    {:ok, {:file_info, _, _, _, _, m_time, _, _, _, _, _, _, _, _}} = :file.read_file_info(path, [:raw])
    NaiveDateTime.from_erl!(m_time)
  end

end
