# LoggerFileBackend

[![Module Version](https://img.shields.io/hexpm/v/logger_file_backend.svg)](https://hex.pm/packages/logger_file_backend)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/logger_file_backend/)
[![Total Download](https://img.shields.io/hexpm/dt/logger_file_backend.svg)](https://hex.pm/packages/logger_file_backend)
[![License](https://img.shields.io/hexpm/l/logger_file_backend.svg)](https://github.com/onkel-dirtus/logger_file_backend/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/onkel-dirtus/logger_file_backend.svg)](https://github.com/onkel-dirtus/logger_file_backend/commits/master)

A simple Elixir `Logger` backend which writes logs to a file. It does not handle log rotation, but it does tolerate log file renames, so it can be used in conjunction with external log rotation.

**Note** The renaming of log files does not work on Windows, because `File.Stat.inode` is used to determine whether the log file has been (re)moved and, on non-Unix, `File.Stat.inode` is always 0.

**Note** If you are running this with the Phoenix framework, please review the Phoenix specific instructions later on in this file.

## Configuration

`LoggerFileBackend` is a custom backend for the elixir `:logger` application. As
such, it relies on the `:logger` application to start the relevant processes.
However, unlike the default `:console` backend, we may want to configure
multiple log files, each with different log levels, formats, etc. Also, we want
`:logger` to be responsible for starting and stopping each of our logging
processes for us. Because of these considerations, there must be one `:logger`
backend configured for each log file we need. Each backend has a name like
`{LoggerFileBackend, id}`, where `id` is any elixir term (usually an atom).

For example, let's say we want to log error messages to
`"/var/log/my_app/error.log"`. To do that, we will need to configure a backend.
Let's call it `{LoggerFileBackend, :error_log}`.

Our `config.exs` would have an entry similar to this:

```elixir
# tell logger to load a LoggerFileBackend processes
config :logger,
  backends: [{LoggerFileBackend, :error_log}]
```

With this configuration, the `:logger` application will start one `LoggerFileBackend`
named `{LoggerFileBackend, :error_log}`. We still need to set the correct file
path and log levels for the backend, though. To do that, we add another config
stanza. Together with the stanza above, we'll have something like this:

```elixir
# tell logger to load a LoggerFileBackend processes
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

* `path` - the path to the log file
* `level` - the logging level for the backend
* `format` - the logging format for the backend
* `metadata` - the metadata to include
* `metadata_filter` - metadata terms which must be present in order to log
* metadata_reject - metadata terms which must be present in order to do not log

### Examples

#### Runtime configuration

```elixir
Logger.add_backend {LoggerFileBackend, :debug}
Logger.configure_backend {LoggerFileBackend, :debug},
  path: "/path/to/debug.log",
  format: ...,
  metadata: ...,
  metadata_filter: ...
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

#### Filtering specific metadata terms

This example only logs `:info` statements originating from the `:ui` OTP app; the `:application` metadata key is auto-populated by `Logger`.

```elixir
config :logger,
  backends: [{LoggerFileBackend, :ui}]

config :logger, :ui,
  path: "/path/to/ui.log",
  level: :info,
  metadata_filter: [application: :ui]
```

This example only writes log statements with a custom metadata key to the file.

```elixir
# in a config file:
config :logger,
  backends: [{LoggerFileBackend, :device_1}]

config :logger, :device_1,
  path: "/path/to/device_1.log",
  level: :debug,
  metadata_filter: [device: 1]

# Usage:
# anywhere in the code:
Logger.info("statement", device: 1)

# or, for a single process, e.g., a GenServer:
# in init/1:
Logger.metadata(device: 1)
# ^ sets device: 1 for all subsequent log statements from this process.

# Later, in other code (handle_cast/2, etc.)
Logger.info("statement") # <= already tagged with the device_1 metadata
```

## Additional Phoenix Configurations

Phoenix makes use of its own `mix.exs` file to track dependencies and additional applications. Add the following to your `mix.exs`:

```elixir
def application do
    [applications: [
      ...,
      :logger_file_backend,
      ...
      ]
    ]
end

defp deps do
  [ ...
    {:logger_file_backend, "~> 0.0.10"},
  ]
end
```

## Copyright and License

Copyright (c) 2014 Kurt Williams

This library licensed under the [MIT license](./LICENSE.md).

## Image Attribution

"log" by Matthew Weatherall from [the Noun Project](https://thenounproject.com/).
