defmodule TaskRunnerClient do
  def run do
    :random.seed(:os.timestamp)
    Task.Supervisor.start_link(name: :task_supervisor)

    1..10
    |> Enum.map(fn(_) -> :random.uniform(1000) - 500 end)
    |> Enum.map(&{:task_supervisor, {Computation, :run, [&1]}})
    |> TaskRunner.run(400)
    |> handle_messages(Aggregator.new)
  end


  defp handle_messages(runner, aggregator) do
    if TaskRunner.done?(runner) do
      {:ok, Aggregator.value(aggregator)}
    else
      receive do
        msg ->
          case TaskRunner.handle_message(runner, msg) do
            nil -> handle_messages(runner, aggregator)

            {{:ok, result}, runner} ->
              handle_messages(runner, Aggregator.add_result(aggregator, result))

            {{:task_error, _reason}, runner} ->
              handle_messages(runner, aggregator)

            {:timeout, _runner} ->
              {:timeout, Aggregator.value(aggregator)}
          end
      end
    end
  end
end