defmodule LoggerMulticastBackend do

  @moduledoc """
  A `Logger` backend that uses multicast UDP to deliver log messages. Originally
  designed for embedded applications, it allows easily watching the log of a
  headless device on the local network.
  
  # easy peazy
  
  in your logger config, simply do something like this:
  
  ```elixir
  config :logger,
    backends: [ :console, LoggerMulticastBackend ]
    level: :debug,
    format: "$time $metadata[$level] $message\n"
  ```
      
  or, at runtime:
  
  ```elixir
  Logger.add_backend LoggerMulticastBackend
  ```  
  
  LoggerMulticastBackend is configured when specified, and suppors the following options:
  
  :target - a tuple of the target unicast or multicast address and port, like {{241,0,0,3}, 2}
  :level - the level to be logged by this backend. Note that messages are first filtered by the general :level configuration in :logger
  :format - the format message used to print logs. Defaults to: "$time $metadata[$level] $levelpad$message\n"
  :metadata - the metadata to be printed by $metadata. Defaults to an empty list (no metadata)
  """
  
  use GenEvent
  require Logger

  @type level     :: Logger.level
  @type format    :: String.t
  @type metadata  :: [atom]  

  @default_target {{224,0,0,224}, 9999}
  @default_format "$time $metadata[$level] $message\n"
  @default_level  :debug
  
  @doc """
  initialize the state of this logger to the environment specified
  in the logger configuration for this backend
  """
  def init({__MODULE__, opts}) do
    target = Keyword.get(opts, :target, @default_target)
    Logger.debug "starting multicast backend on target #{inspect target}"
    {:ok, sender} = GenServer.start_link(LoggerMulticastSender, target)
    state = %{
      sender: sender,
      level: Keyword.get(opts, :level, @default_level),
      format: (Keyword.get(opts, :format, @default_format) |> Logger.Formatter.compile),
      metadata: Keyword.get(opts, :metadata, [])
    }
    {:ok, state}
  end

  def init(__MODULE__), do: init({__MODULE__, []})

  @doc "Add the formatted log entry to the log output queue if it meets our logging criteria"
  def handle_event({level, _gl, {Logger, message, timestamp, metadata}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      entry = format_event(level, message, timestamp, metadata, state)
      :ok = GenServer.cast(state.sender, {:add_entry, entry})
    end
    {:ok, state}
  end

  defp format_event(level, msg, ts, md, %{format: format, metadata: metadata}) do
    Logger.Formatter.format(format, level, msg, ts, Dict.take(md, metadata))
  end

end

