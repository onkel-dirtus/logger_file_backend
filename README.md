LoggerFileBackend
=================

A simple `Logger` backend which writes logs to a file. It does not handle log
rotation for you, but it does tolerate log file renames, so it can be
used in conjunction with external log rotation.

**Note** The following of file renames does not work on Windows, because `File.Stat.inode` is used to determine whether the log file has been (re)moved and, on non-Unix, `File.Stat.inode` is always 0.

## Configuration

`LoggerFileBackend` is a custom backend for the elixir `:logger` application. As
such, it relies on the `:logger` application to start the relevant processes.
However, unlike the default `:console` backend, we may want to configure
multiple log files, each with different log levels formats, etc. Also, we want
`:logger` to be responsible for starting and stopping each of our logging
processes for us. Because of these considerations, there must be one `:logger`
backend configured for each log file we need. Each backend has a name like
`{LoggerFileBackend, id}`, where `id` is any elixir term (usually an atom).

For example, let's say we want to log error messages to
"/var/log/my_app/error.log". To do that, we will need to configure a backend.
Let's call it `{LoggerFileBackend, :error_log}`.

Our config.exs would have an entry similar to this:

```elixir
# tell logger to load a LoggerFileBackend processes
config :logger,
  backends: [{LoggerFileBackend, :error_log}]
```

With this configuration, the `:logger` application will start one `LoggerFileBackend`
named `{LoggerFileBackend, :error_log}`. We still need to set the correct file
path and log levels for the backend, though. To do that, we add another config
stanza. Together with the stanzaabove, we'll have something like this:

```elixir
# tell logger to load 2 LoggerFileBackend processes
config :logger,
  backends: [{LoggerFileBackend, :error_log}]

# configuration for the {LoggerFileBackend, :error_log} backend
config :logger, :error_log,
  path: "/var/log/my_app/error.log",
  level: :error
```

Check out the examples below for runtime configuration and configuration for
multiple log files.

`LoggerFileBackend` supports the following configuration values:

* path - the path to the log file
* level - the logging level for the backend
* format - the logging format for the backend
* metadata - the metadata to include


### Examples

#### Runtime configuration

```elixir
Logger.add_backend {LoggerFileBackend, :debug}
Logger.configure {LoggerFileBackend, :debug},
  path: "/path/to/debug.log",
  format: ...,
  metadata: ...
```

#### Application config for multiple log files

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
