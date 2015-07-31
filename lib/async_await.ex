defmodule AsyncAwait do
  def run do
    :random.seed(:os.timestamp)

    1..10
    |> Enum.map(fn(_) -> :random.uniform(1000) end)
    |> Enum.map(&Task.async(fn -> Computation.run(&1) end))
    |> Enum.map(&Task.await/1)
    |> Enum.reduce(Aggregator.new, &Aggregator.add_result(&2, &1))
    |> Aggregator.value
  end
end