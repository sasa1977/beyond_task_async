defmodule TaskRunner do
  def run(specs, timeout \\ 5000) do
    %{
      work_ref: make_ref,
      timeout_ref: make_ref,
      tasks: [],
      timer: nil,
      done: false
    }
    |> start_tasks(specs)
    |> start_timer(timeout)
  end

  defp start_tasks(%{work_ref: work_ref} = runner, specs) do
    %{runner | tasks: Enum.map(specs, &start_task(work_ref, &1))}
  end

  defp start_task(work_ref, {task_supervisor, fun_or_mfa}) do
    {:ok, pid} = Task.Supervisor.start_child(
      task_supervisor,
      __MODULE__, :run_task, [work_ref, self, fun_or_mfa]
    )

    Process.monitor(pid)
    pid
  end

  def run_task(work_ref, caller, fun_or_mfa) do
    send(caller, {work_ref, self, do_run_task(fun_or_mfa)})
  end

  defp do_run_task(fun) when is_function(fun), do: fun.()
  defp do_run_task({m, f, a}), do: apply(m, f, a)

  defp start_timer(runner, :infinity), do: runner
  defp start_timer(%{timeout_ref: timeout_ref} = runner, timeout) do
    %{runner | timer: Process.send_after(self, {:timeout, timeout_ref}, timeout)}
  end


  def done?(%{done: done}), do: done


  def handle_message(%{done: true}, _), do: nil

  def handle_message(%{timeout_ref: timeout_ref} = runner, {:timeout, timeout_ref}) do
    {:timeout, finish(%{runner | timer: nil})}
  end

  def handle_message(%{tasks: tasks} = runner, {:DOWN, _, _, pid, reason}) do
    if Enum.member?(tasks, pid) do
      runner
      |> remove(pid)
      |> respond({:task_error, reason})
    else
      nil
    end
  end

  def handle_message(%{work_ref: work_ref} = runner, {work_ref, task, result}) do
    runner
    |> remove(task)
    |> respond({:ok, result})
  end

  def handle_message(_, _), do: nil


  defp remove(%{tasks: tasks} = runner, task) do
    %{runner | tasks: List.delete(tasks, task)}
  end


  defp respond(%{tasks: []} = runner, status) do
    {status, finish(runner)}
  end

  defp respond(runner, status) do
    {status, runner}
  end

  defp finish(runner) do
    runner
    |> cancel_timer
    |> Map.put(:done, true)
  end

  defp cancel_timer(%{timer: nil} = runner), do: runner
  defp cancel_timer(%{timer: timer, timeout_ref: timeout_ref} = runner) do
    :erlang.cancel_timer(timer)
    receive do
      {:timeout, ^timeout_ref} -> :ok
      after 0 -> :ok
    end
    %{runner | timer: nil}
  end
end