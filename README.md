# LoggerMulticastBackend

An Elixir `Logger` backend that uses multicast UDP to deliver log messages.
Designed for headless embedded applications, it allows watching the
log over the local network.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `logger_multicast_backend` to your list of dependencies in `mix.exs`:

    ```elixir
      def deps do
        [{:logger_multicast_backend, "~> 0.2.1"}]
      end
    ```

  2. Add backend to Logger

    ```elixir
      Logger.add_backend LoggerMulticastBackend
    ```

## Defaults

In your logger config, simply do something like this:

```elixir
  config :logger,
    backends: [ :console, LoggerMulticastBackend ],
    level: :debug,
    format: "$time $metadata[$level] $message\n"
```

or, add the backend at runtime:

```elixir
  Logger.add_backend LoggerMulticastBackend
```

Now, you'll have logging messages sent out on the default target multicast
address, which is 224,0,0,224:9999.

## Configuration

A `Logger` backend that uses multicast UDP to deliver log messages. Originally
designed for embedded applications, it allows easily watching the log of a
headless device on the local network.

in your logger config, simply do something like this:

```elixir
  config :logger,
    backends: [ :console, LoggerMulticastBackend ]
    level: :debug,
    format: "$time $metadata[$level] $message\n"
  config :logger_multicast_backend,
    target: {{224,0,0,220}, 514},
    interface: {192,168,1,50},
    metadata: [:line, :file]
```

or, at runtime:

```elixir
  Logger.add_backend LoggerMulticastBackend
  Logger.configure_backend LoggerMulticastBackend, [target: {{224,0,0,220}, 514}, interface: {192,168,1,50}]
```

LoggerMulticastBackend is configured when specified, and supports the following options:

`:target` - a tuple of the target unicast or multicast address and port. Defaults to: {{224,0,0,224}, 9999}

`:interface` - If the host has more then one network interfaces, specify which one to use by IP address. Defaults to: {0,0,0,0}

`:level` - the level to be logged by this backend. _Note that messages are first filtered by the general `:level` configuration in `:logger`_. Defaults to: :debug

`:format` - the format message used to print logs. Defaults to: "$time $metadata[$level] $levelpad$message\n"

`:metadata` - the metadata to be printed by $metadata. Defaults to: \[\] (no metadata)