defmodule SupervisedTask do
  def run do
    :random.seed(:os.timestamp)
    Task.Supervisor.start_link(name: :task_supervisor)

    work_ref = make_ref

    1..10
    |> Enum.map(fn(_) -> :random.uniform(1000) - 500 end)
    |> Enum.map(&start_computation(work_ref, &1))
    |> collect_results(work_ref)
  end

  defp start_computation(work_ref, arg) do
    caller = self

    {:ok, pid} = Task.Supervisor.start_child(
      :task_supervisor,
      fn ->
        result = Computation.run(arg)
        send(caller, {work_ref, self, result})
      end
    )

    Process.monitor(pid)

    pid
  end

  defp collect_results(tasks, work_ref) do
    timeout_ref = make_ref
    timer = Process.send_after(self, {:timeout, timeout_ref}, 400)
    try do
      collect_results(tasks, work_ref, Aggregator.new, timeout_ref)
    after
      :erlang.cancel_timer(timer)
      receive do
        {:timeout, ^timeout_ref} -> :ok
        after 0 -> :ok
      end
    end
  end

  defp collect_results([], _, aggregator, _), do: {:ok, Aggregator.value(aggregator)}
  defp collect_results(tasks, work_ref, aggregator, timeout_ref) do
    receive do
      {:timeout, ^timeout_ref} ->
        {:timeout, Aggregator.value(aggregator)}

      {:DOWN, _, _, pid, _} ->
        if Enum.member?(tasks, pid) do
          collect_results(List.delete(tasks, pid), work_ref, aggregator, timeout_ref)
        else
          collect_results(tasks, work_ref, aggregator, timeout_ref)
        end

      {^work_ref, task, result} ->
        collect_results(
          List.delete(tasks, task),
          work_ref,
          Aggregator.add_result(aggregator, result),
          timeout_ref
        )
    end
  end
end