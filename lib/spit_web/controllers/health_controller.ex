defmodule SpitWeb.HealthController do
  use SpitWeb, :controller

  def live(conn, _params) do
    json(conn, %{status: "ok"})
  end

  def ready(conn, _params) do
    checks = [
      {:endpoint, Process.whereis(SpitWeb.Endpoint)},
      {:pubsub, Process.whereis(Spit.PubSub)},
      {:repo, Process.whereis(Spit.Repo)},
      {:rate_limiter, Process.whereis(Spit.RateLimiter)},
      {:cleanup_worker, Process.whereis(Spit.Pastes.CleanupWorker)}
    ]

    failed =
      checks
      |> Enum.filter(fn {_name, pid} -> is_nil(pid) or not Process.alive?(pid) end)
      |> Enum.map(fn {name, _pid} -> Atom.to_string(name) end)

    if failed == [] do
      json(conn, %{status: "ready"})
    else
      conn
      |> put_status(:service_unavailable)
      |> json(%{status: "not_ready", failed_checks: failed})
    end
  end
end
