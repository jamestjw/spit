defmodule SpitWeb.PasteController do
  use SpitWeb, :controller

  alias Spit.Pastes

  def create(conn, params) do
    with {:ok, body, conn} <- request_body(conn),
         false <- blank?(body),
         {:ok, paste} <-
           Pastes.create_paste(%{
             body: body,
             content_type: content_type(conn),
             expires_at: Pastes.expires_at_from_ttl(params["ttl"])
           }) do
      url = url(~p"/p/#{paste.slug}")

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
        |> send_resp(:payload_too_large, "paste body is too large\n")

      {:error, _reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:bad_request, "could not read request body\n")
    end
  end

  def show(conn, %{"slug" => slug}) do
    case Pastes.get_active_paste_by_slug(slug) do
      nil -> send_resp(conn, :not_found, "paste not found")
      paste -> render(conn, :show, paste: paste)
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
    {:ok, raw_body |> Enum.reverse() |> IO.iodata_to_binary(), conn}
  end

  defp request_body(conn), do: read_body(conn, length: 1_000_000)

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
