defmodule LoggerMulticastBackendTest.Listener do
  use GenServer

  def start(args \\ []) do
    case GenServer.start_link __MODULE__, args, name: TestListener do
      {:error, {:already_started, pid}} ->
        {:ok, pid}
      ret ->
        ret
    end
  end

  def init(_args) do
    open_socket()
    {:ok, []}
  end

  def handle_info({:udp, _socket, _ip, _port, data}, state) do
    {:noreply, state ++ [data]}
  end

  def handle_call(:get_line, _from, []) do
    {:reply, nil, []}
  end
  def handle_call(:get_line, _from, state) do
    [h | t] = state
    {:reply, h, t}
  end

  defp open_socket do
    :gen_udp.open(9999, [
      :binary,
      {:active, true},
      {:recbuf, 65536},
  	  {:reuseaddr, true},
      {:add_membership, {{224,0,0,224}, {0,0,0,0}}}
    ])
  end
end