defmodule LoggerMulticastBackend.Sender do

  @moduledoc """
  `GenStage` `Consumer` that implements the sending-server for the LoggerMulticastBackend.
  Provides a managed timer-based sender for multicast logs as well as UDP socket management.
  """

  alias Experimental.GenStage
  use GenStage

  @socket_retry_time  1000      # milliseconds between port open attempts
  @packet_pacer_time  10        # milliseconds between multicasts

  @socket_opts [:binary, {:broadcast, true}, {:active, false}, {:reuseaddr, true} ]

  @doc "Init `Consumer` with target to send lines one and interface to bind socket to"
  def init([target: target, interface: interface]) do
    state = %{target: target, socket: nil, interface: interface}
    {:consumer, state}
  end

  @doc "Handles lines (events) received from `GenStage` `Producer`. Sends out on timer-based spacing"
  def handle_events(events, _from, state) do
    for e <- events do
      Process.send_after(self, {:send, e}, @packet_pacer_time)
    end
    {:noreply, [], state}
  end

  def handle_call({:configure, target, interface}, _from, state) do
    if state.socket, do: :gen_udp.close state.socket
    opts = @socket_opts ++ [{:ip, interface}] |> List.flatten
    case :gen_udp.open(0, opts) do
      {:ok, socket} ->
        {:reply, :ok, [], %{state | target: target, interface: interface, socket: socket}}
      _ ->
        {:reply, :ok, [], %{state | target: target, interface: interface}}
    end
  end

  @doc false
  # Handles request to send line with no socket defined - attempt to open it
  def handle_info({:send, line}, %{socket: nil} = state) do
    opts = @socket_opts ++ [{:ip, state.interface}] |> List.flatten
    case :gen_udp.open(0, opts) do
      {:ok, socket} ->
        state =  %{state | socket: socket}
        send_line(line, state)
        {:noreply, [], state}
      _ ->
        Process.send_after(self, {:send, line}, @socket_retry_time)
        {:noreply, [], state}
    end
  end

  @doc false
  # handle a request to send line with a valid socket - attempt to write to it
  def handle_info({:send, line}, state) do
    {:noreply, [], send_line(line, state)}
  end

  @doc false
  def terminate(msg, state) do
    IO.write "#{__MODULE__} terminating due to: #{inspect msg}\n"
    if state.socket, do: :gen_udp.close state.socket
    :ok
  end

  #Sends line out existing socket
  defp send_line(line, %{socket: socket, target: {addr, port}} = state) do
    case :gen_udp.send(socket, addr, port, line) do
      :ok ->
        state
      _ ->
        :gen_udp.close socket
        %{state | socket: nil}
    end
  end

end
