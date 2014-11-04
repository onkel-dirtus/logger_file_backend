LoggerFileBackend
=================

A simple `Logger` backend which writes logs to a file. It does not handle log
rotation for you, but it does tolerate log file renames, so it can be
used in conjunction with external log rotation.

**Note** The following of file renames does not work on Windows, because `File.Stat.inode` is used to determine whether the log file has been (re)moved and, on non-Unix, `File.Stat.inode` is always 0.

## Configuration

`LoggerFileBackend` is a custom backend for the elixir `:logger` application. As
such, it relies on the `:logger` application to start the relevant processes.
However, unlike the default `:console` backend, we may want to configure multiple
log files, each with different log levels formats, etc. Also, we want `:logger`
to be responsible for starting and stopping each of our logging processes for us.
Because of these considerations, there must be one `:logger` backend configured
for each log file we need. Each backend has a name in the following format:
`{LoggerFileBackend, id}`, where `id` is any elixir term (usually an atom).

For example, let's say we want to log error messages to "/var/log/my_app/error.log"
and info messages to "/var/log/my_app/info.log". To do that, we will need 2 `:logger`
backends. Let's call them `{LoggerFileBackend, :error_log}` and `{LoggerFileBackend, :info_log}`.
Our config.exs would have an entry similar to this:

```elixir
# tell logger to load 2 LoggerFileBackend processes
config :logger,
  backends: [{LoggerFileBackend, :error_log},
             {LoggerFileBackend, :info_log}]
```

With this configuration, the `:logger` application will start 2 `LoggerFileBackend`s, one
named `{LoggerFileBackend, :error_log}` and another named `{LoggerFileBackend, :info_log}`.
We still need a way to set the correct file path and log levels for each of them.
To do that, we add another config stanza for each backend. Together with the stanza
above, we'll have something like this:

```elixir
# tell logger to load 2 LoggerFileBackend processes
config :logger,
  backends: [{LoggerFileBackend, :error_log},
             {LoggerFileBackend, :info_log}]

# configuration for the {LoggerFileBackend, :error_log} backend
config :logger, :error_log,
  path: "/var/log/my_app/error.log",
  level: :error

# configuration for the {LoggerFileBackend, :info_log} backend
config :logger, :info_log,
  path: "/var/log/my_app/info.log",
  level: :info
```

I think that covers it...


`LoggerFileBackend` supports the following configuration values:

* path - the path to the log file
* level - the logging level for the backend
* format - the logging format for the backend
* metadata - the metadata to include


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
