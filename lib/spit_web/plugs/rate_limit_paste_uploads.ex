defmodule SpitWeb.Plugs.RateLimitPasteUploads do
  @moduledoc false

  import Plug.Conn

  alias Spit.RateLimiter

  def init(opts), do: opts

  def call(%{method: method, request_path: path} = conn, _opts)
      when {method, path} in [{"POST", "/api/pastes"}, {"PUT", "/"}] do
    ip = client_ip(conn)
    limits = Application.get_env(:spit, :paste_upload_limits, [])

    with :ok <-
           check_upload_limit(
             ip,
             :minute,
             Keyword.get(limits, :uploads_per_minute, 10),
             :timer.minutes(1)
           ),
         :ok <-
           check_upload_limit(
             ip,
             :day,
             Keyword.get(limits, :uploads_per_day, 100),
             :timer.hours(24)
           ) do
      conn
    else
      {:error, retry_after_ms} -> rate_limited(conn, retry_after_ms)
    end
  end

  def call(conn, _opts), do: conn

  def client_ip(conn) do
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
  end

  defp check_upload_limit(ip, window, limit, scale_ms) do
    case RateLimiter.hit("paste_uploads:#{window}:#{ip}", limit, scale_ms) do
      {:allow, _remaining} -> :ok
      {:deny, retry_after_ms} -> {:error, retry_after_ms}
    end
  end

  defp rate_limited(conn, retry_after_ms) do
    retry_after_seconds = retry_after_ms |> div(1000) |> max(1) |> Integer.to_string()

    conn
    |> put_resp_header("retry-after", retry_after_seconds)
    |> put_resp_content_type("text/plain")
    |> send_resp(:too_many_requests, "rate limit exceeded, try again later\n")
    |> halt()
  end
end
