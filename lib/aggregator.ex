defmodule Aggregator do
  def new, do: 0
  def value(aggregator), do: aggregator

  def add_result(aggregator, result) do
    :timer.sleep(50)
    aggregator + result
  end
end