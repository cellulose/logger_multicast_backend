defmodule LoggerMulticastBackend do

  @moduledoc """
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

  :target - a tuple of the target unicast or multicast address and port. Defaults to: {{224,0,0,224}, 9999}

  :interface - If the host has many network interfaces, specify which one to use by IP address. Defaults to: {0,0,0,0}

  :level - the level to be logged by this backend. _Note that messages are first filtered by the general `:level` configuration in `:logger`_. Defaults to: :debug

  :format - the format message used to print logs. Defaults to: "$time $metadata[$level] $levelpad$message\n"

  :metadata - the metadata to be printed by $metadata. Defaults to: [] (no metadata)
  """

  use GenEvent
  alias Experimental.GenStage
  require GenStage
  require Logger

  @metadata Application.get_env(:logger_multicast_backend, :metadata, [])
  @format Application.get_env(:logger_multicast_backend, :format, "$time $metadata[$level] $message\n")
  @level Application.get_env(:logger_multicast_backend, :level, :debug)
  @target Application.get_env(:logger_multicast_backend, :target, {{224,0,0,224}, 9999})
  @interface Application.get_env(:logger_multicast_backend, :interface, {0,0,0,0})

  @defaults %{format: @format, metadata: @metadata, level: @level, target: @target, interface: @interface}

  @doc false
  def init(__MODULE__), do: init({__MODULE__, []})

  @doc """
  initialize the state of this logger to the configuration options provided
  """
  def init({__MODULE__, opts}) do
    #Setup state
    state =
      configure(opts, @defaults)

    #Setup GenStage Flow
    {:ok, queue} = GenStage.start_link(LoggerMulticastBackend.Queue, [])
    {:ok, sender} = GenStage.start_link(LoggerMulticastBackend.Sender, [target: state.target, interface: state.interface])
    GenStage.sync_subscribe(sender, [to: queue, min_demand: 5, max_demand: 10])

    #Add Queue Consumer to state
    state =
      state
      |> Map.merge(%{queue: queue})
    {:ok, state}
  end

  @doc """
  GenEvent callback to handle runtime configuration of this Backend
  """
  def handle_call({:configure, options}, %{queue: queue} = state) do
    state =
      configure(options, state)
      |> Map.merge(%{queue: queue})
    {:ok, :ok, state}
  end

  @doc "Add the formatted log entry to the log output queue if it meets our logging criteria"
  def handle_event({level, _gl, {Logger, message, timestamp, metadata}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      entry = format_event(level, message, timestamp, metadata, state)
      :ok = GenStage.cast(state.queue, {:enqueue, entry})
    end
    {:ok, state}
  end

  @doc """
  GenEvent callback to handle flushing of the Backend
  """
  def handle_event(:flush, state) do
    GenStage.cast(state.queue, :flush)
    {:ok, state}
  end

  # Format the event using the specified Logger, metadata and output string
  defp format_event(level, msg, ts, md, %{format: format, metadata: metadata}) do
    Logger.Formatter.format(format, level, msg, ts, take_metadata(md, metadata))
  end

  # Take specified metadata keys from provided metadata
  defp take_metadata(metadata, keys) do
    metadatas = Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error     -> acc
      end
    end)
    Enum.reverse(metadatas)
  end

  # Extracts configuration options from Dict and returns Map
  # Used defaults provided for any options not provided
  defp configure(opts, defaults) do
    level = Dict.get(opts, :level, defaults.level)
    target = Dict.get(opts, :target, defaults.target)
    interface = Dict.get(opts, :interface, defaults.interface)
    format = case Dict.get(opts, :format, defaults.format) do
      f when is_list(f) -> f
      f -> Logger.Formatter.compile f
    end
    metadata = Dict.get(opts, :metadata, defaults.metadata)
    %{format: format, metadata: metadata, level: level, target: target, interface: interface}
  end
end
