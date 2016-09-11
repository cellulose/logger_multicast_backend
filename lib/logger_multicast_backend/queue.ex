defmodule LoggerMulticastBackend.Queue do
  @moduledoc """
  A `GenStage` `producer` that implements a FIFO queue that dispatches to a `consumer`
  each line individual based on the demand requested.
  """
  alias Experimental.GenStage
  use GenStage

  @max_queue_len 1024 # maximum lines to save in the queue

  @doc """
  Initilizes module with empty queue
  """
  def init(_) do
    {:producer, {:queue.new, 0}}
  end

  ## Callbacks

  @doc """
  Add logger line to send queue
  """
  def handle_cast({:enqueue, line}, {queue, demand}) do
    queue = :queue.in(line, queue)
    queue = case :queue.len(queue) do
      q when  q >= @max_queue_len ->
        #Discard oldest line if queue has reached max
        {{:value, _line}, queue} = :queue.out(queue)
        queue
      _ -> queue
    end
    dispatch_lines(queue, demand, [])
  end

  @doc """
  Flush the queue - remove all lines currently in queue and reset demand
  """
  def handle_cast(:flush, {_queue, _demand}) do
    #REVIEW: Make sure old queue will get garbage collected or this is a memory leak
    {:noreply, [], {:queue.new, 0}}
  end

  @doc "GenStage callback to handle demand request from consumer"
  def handle_demand(incoming_demand, {queue, demand}) do
    dispatch_lines(queue, incoming_demand + demand, [])
  end

  # Dispatches lines to consumer from the queue
  defp dispatch_lines(queue, demand, lines) do
    with d when d > 0 <- demand,
         {{:value, line}, queue} <- :queue.out(queue) do
      dispatch_lines(queue, demand - 1, [line | lines])
    else
      _ ->
        {:noreply, Enum.reverse(lines), {queue, demand}}
    end
  end
end
