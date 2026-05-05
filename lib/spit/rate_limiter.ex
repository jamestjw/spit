defmodule Spit.RateLimiter do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def hit(bucket, limit, scale_ms, cost \\ 1) do
    GenServer.call(__MODULE__, {:hit, bucket, limit, scale_ms, cost})
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:hit, bucket, limit, scale_ms, cost}, _from, counters) do
    now = System.monotonic_time(:millisecond)

    {count, expires_at} = Map.get(counters, bucket, {0, now + scale_ms})
    {count, expires_at} = if expires_at <= now, do: {0, now + scale_ms}, else: {count, expires_at}
    new_count = count + cost

    if new_count <= limit do
      {:reply, {:allow, limit - new_count}, Map.put(counters, bucket, {new_count, expires_at})}
    else
      {:reply, {:deny, max(expires_at - now, 0)}, counters}
    end
  end

  def handle_call(:reset, _from, _counters), do: {:reply, :ok, %{}}
end
