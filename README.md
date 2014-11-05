LoggerFileBackend
=================

A simple `Logger` backend which writes logs to a file. It does not handle log
rotation for you, but it does tolerate log file renames, so it can be
used in conjunction with external log rotation.

**Note** The following of file renames does not work on Windows, because `File.Stat.inode` is used to determine whether the log file has been (re)moved and, on non-Unix, `File.Stat.inode` is always 0.

## Configuration

`LoggerFileBackend` supports the following configuration values:

* path - the path to the log file
* level - the logging level for the backend
* format - the logging format for the backend
* metadata - the metadata to include
* size - the maximum size of each log file, in bytes, default 10485760 (10MB)
* count - the maximum numbers of log files, default 10
* check_interval - the interval of checking rotation, in milliseconds, default 600,000 (10 minutes)


### Runtime configuration for mutiple log files

```elixir
backends =[debug: [path: "/path/to/debug.log", format: ..., metadata: ...],
           error: [path: "/path/to/error.log", format: ..., metadata: ...]]

for {id, opts} <- backends do
  backend = {LoggerFileBackend, id}
  Logger.add_backend(backend)
  Logger.configure(backend, opts)
end
```

### Application config for multiple log files

```elixir
config :logger,
  backends: [{LoggerFileBackend, :info},
             {LoggerFileBackend, :error}]

config :logger, :info,
  path: "/path/to/info.log",
  level: :info

config :logger, :error,
  path: "/path/to/error.log",
  level: :error
```

