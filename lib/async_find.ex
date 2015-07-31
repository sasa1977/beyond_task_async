defmodule AsyncFind do
  def run do
    :random.seed(:os.timestamp)

    1..10
    |> Enum.map(fn(_) -> :random.uniform(1000) end)
    |> Enum.map(&Task.async(fn -> Computation.run(&1) end))
    |> collect_results
  end

  defp collect_results(tasks, aggregator \\ Aggregator.new)

  defp collect_results([], aggregator), do: Aggregator.value(aggregator)
  defp collect_results(tasks, aggregator) do
    receive do
      msg ->
        case Task.find(tasks, msg) do
          {result, task} ->
            collect_results(
              List.delete(tasks, task),
              Aggregator.add_result(aggregator, result)
            )

          nil ->
            collect_results(tasks, aggregator)
        end
    end
  end
end