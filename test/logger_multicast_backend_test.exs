Code.require_file "listener.ex", __DIR__
defmodule LoggerMulticastBackendTest do

  use ExUnit.Case
  require Logger

  setup do
    LoggerMulticastBackendTest.Listener.start
    Logger.configure_backend LoggerMulticastBackend, [format: "$metadata[$level] $message\n"]
    :ok
  end

  test "test debug message" do
    Logger.debug "A debug message"
    :timer.sleep 20
    line = GenServer.call TestListener, :get_line
    assert line == "[debug] A debug message\n"
  end

  test "test info message" do
    Logger.info "A info message"
    :timer.sleep 20
    line = GenServer.call TestListener, :get_line
    assert line == "[info] A info message\n"
  end

  test "info event with error level" do
    Logger.configure_backend LoggerMulticastBackend, [level: :error]
    Logger.info "A info message"
    :timer.sleep 20
    line = GenServer.call TestListener, :get_line
    assert line == nil
  end

end

