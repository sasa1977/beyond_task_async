defmodule Timeout do
  def run do
    :random.seed(:os.timestamp)

    1..10
    |> Enum.map(fn(_) -> :random.uniform(1000) end)
    |> Enum.map(&Task.async(fn -> Computation.run(&1) end))
    |> collect_results
  end

  defp collect_results(tasks) do
    timeout_ref = make_ref
    timer = Process.send_after(self, {:timeout, timeout_ref}, 900)
    try do
      collect_results(tasks, Aggregator.new, timeout_ref)
    after
      :erlang.cancel_timer(timer)
      receive do
        {:timeout, ^timeout_ref} -> :ok
        after 0 -> :ok
      end
    end
  end

  defp collect_results([], aggregator, _), do: {:ok, Aggregator.value(aggregator)}
  defp collect_results(tasks, aggregator, timeout_ref) do
    receive do
      {:timeout, ^timeout_ref} ->
        {:timeout, Aggregator.value(aggregator)}
      msg ->
        case Task.find(tasks, msg) do
          {result, task} ->
            collect_results(
              List.delete(tasks, task),
              Aggregator.add_result(aggregator, result),
              timeout_ref
            )

          nil -> collect_results(tasks, aggregator, timeout_ref)
        end
    end
  end
end