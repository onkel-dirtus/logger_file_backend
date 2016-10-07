defmodule LoggerFileBackend.JsonFormatter do

    def compile(_str) do
        [:json]
    end

    defp format_timestamp({{year, mo, day}, {hour, min, sec, ms}}) do
        # convert timestamp to a string if it's still a raw string
        "#{year}-#{mo}-#{day}T#{hour}:#{min}:#{sec}.#{ms}"
    end
    defp format_timestamp(time_str) when is_binary(time_str) do
        # if it was already formatted as a string in the backend
        time_str
    end

    def format(_cfg, lvl, raw_msg, raw_ts, meta) do
        # flatten out msg if it's a list of strings
        msg = "#{raw_msg}"

        # convert timestamp to a string
        # do nothing if the backend already formatted it as a string
        tss = format_timestamp(raw_ts)

        data = Enum.into(meta, %{})
        box = %{:lvl => lvl, :msg => msg, :ts => tss, :data => data}
        line = Poison.encode!(box)
        "#{line}\n"
    end

    def prune(bin) do
        # not really sure what this should do
        bin
    end

end
