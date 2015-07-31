defmodule Computation do
  def run(x) when x > 0 do
    :timer.sleep(x)
    x
  end
end