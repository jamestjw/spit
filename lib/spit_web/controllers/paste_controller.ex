defmodule SpitWeb.PasteController do
  use SpitWeb, :controller

  alias Spit.Pastes

  def create(conn, params) do
    with {:ok, body, conn} <- request_body(conn),
         false <- blank?(body),
         {:ok, expires_at} <- Pastes.ttl_expires_at(params["ttl"]),
         :ok <- check_byte_limit(conn, body),
         {:ok, paste} <-
           Pastes.create_paste(%{
             body: body,
             content_type: content_type(conn),
             expires_at: expires_at,
             encrypted: params["encrypted"] == "true"
           }) do
      url =
        if params["raw"] in ["true", "1"] do
          url(~p"/raw/#{paste.slug}")
        else
          url(~p"/p/#{paste.slug}")
        end

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(:created, url <> "\n")
    else
      true ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:bad_request, "paste body cannot be empty\n")

      {:more, _partial, conn} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(413, "paste body is too large\n")

      {:error, message} when is_binary(message) ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:bad_request, message <> "\n")

      {:error, _reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:bad_request, "could not read request body\n")

      {:rate_limited, retry_after_ms} ->
        retry_after_seconds = retry_after_ms |> div(1000) |> max(1) |> Integer.to_string()

        conn
        |> put_resp_header("retry-after", retry_after_seconds)
        |> put_resp_content_type("text/plain")
        |> send_resp(:too_many_requests, "rate limit exceeded, try again later\n")
    end
  end

  def show(conn, %{"slug" => slug}) do
    case Pastes.get_active_paste_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(:not_found)

      paste ->
        render(conn, :show, paste: paste, page_url: url(~p"/p/#{slug}"))
    end
  end

  def raw(conn, %{"slug" => slug}) do
    case Pastes.get_active_paste_by_slug(slug) do
      nil ->
        send_resp(conn, :not_found, "paste not found\n")

      paste ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:ok, paste.body)
    end
  end

  def download(conn, %{"slug" => slug}) do
    case Pastes.get_active_paste_by_slug(slug) do
      nil ->
        send_resp(conn, :not_found, "paste not found\n")

      paste ->
        conn
        |> put_resp_content_type("text/plain")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{paste.slug}.txt"))
        |> send_resp(:ok, paste.body)
    end
  end

  defp request_body(%{assigns: %{raw_body: raw_body}} = conn) do
    body = raw_body |> Enum.reverse() |> IO.iodata_to_binary()

    if byte_size(body) > max_body_bytes() do
      {:more, body, conn}
    else
      {:ok, body, conn}
    end
  end

  defp request_body(conn), do: read_body(conn, length: max_body_bytes())

  defp max_body_bytes do
    :spit
    |> Application.get_env(:paste_upload_limits, [])
    |> Keyword.get(:max_body_bytes, 1_000_000)
  end

  defp check_byte_limit(conn, body) do
    ip = SpitWeb.Plugs.RateLimitPasteUploads.client_ip(conn)
    limits = Application.get_env(:spit, :paste_upload_limits, [])
    limit = Keyword.get(limits, :bytes_per_hour, 5 * 1024 * 1024)

    case Spit.RateLimiter.hit(
           "paste_upload_bytes:hour:#{ip}",
           limit,
           :timer.hours(1),
           byte_size(body)
         ) do
      {:allow, _remaining} -> :ok
      {:deny, retry_after_ms} -> {:rate_limited, retry_after_ms}
    end
  end

  defp blank?(body), do: String.trim(body) == ""

  defp content_type(conn) do
    conn
    |> get_req_header("content-type")
    |> List.first()
    |> case do
      nil -> "text/plain"
      value -> value
    end
  end
end
