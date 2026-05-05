defmodule Spit.Pastes.CleanupWorker do
  @moduledoc false

  use GenServer

  alias Spit.Pastes

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if enabled?() do
      schedule_cleanup(0)
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Pastes.delete_expired_pastes()
    schedule_cleanup(interval_ms())

    {:noreply, state}
  end

  defp schedule_cleanup(delay_ms), do: Process.send_after(self(), :cleanup, delay_ms)

  defp enabled? do
    Application.get_env(:spit, :paste_cleanup_enabled, true)
  end

  defp interval_ms do
    Application.get_env(:spit, :paste_cleanup_interval_ms, :timer.hours(1))
  end
end
