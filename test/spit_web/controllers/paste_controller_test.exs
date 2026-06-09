defmodule SpitWeb.PasteControllerTest do
  use SpitWeb.ConnCase, async: true

  alias Spit.Pastes

  describe "POST /api/pastes" do
    test "accepts raw curl-style request bodies and returns a browser URL", %{conn: conn} do
      conn =
        conn
        |> put_remote_ip({203, 0, 113, 1})
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/pastes", "line one\nline two\n")

      assert response(conn, 201) =~ ~r|http://localhost:4000/p/[A-Za-z0-9_-]{8}\n|
    end

    test "still accepts explicit text/plain request bodies", %{conn: conn} do
      conn =
        conn
        |> put_remote_ip({203, 0, 113, 2})
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes", "plain text body\n")

      assert response(conn, 201) =~ ~r|http://localhost:4000/p/[A-Za-z0-9_-]{8}\n|
    end

    test "accepts short curl -T- uploads to the site root", %{conn: conn} do
      conn =
        conn
        |> put_remote_ip({203, 0, 113, 8})
        |> put_req_header("content-type", "text/plain")
        |> put(~p"/", "short upload body\n")

      assert response(conn, 201) =~ ~r|http://localhost:4000/p/[A-Za-z0-9_-]{8}\n|
    end

    test "rejects empty bodies", %{conn: conn} do
      conn =
        conn
        |> put_remote_ip({203, 0, 113, 3})
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes", "   \n")

      assert response(conn, 400) == "paste body cannot be empty\n"
    end

    test "rejects request bodies over the configured max size", %{conn: conn} do
      conn =
        conn
        |> put_remote_ip({203, 0, 113, 10})
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes", String.duplicate("x", 41))

      assert response(conn, 413) == "paste body is too large\n"
    end

    test "rejects ttl=never", %{conn: conn} do
      conn =
        conn
        |> put_remote_ip({203, 0, 113, 6})
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes?ttl=never", "body")

      assert response(conn, 400) == "ttl=never is not allowed\n"
    end

    test "rejects ttls over one week", %{conn: conn} do
      conn =
        conn
        |> put_remote_ip({203, 0, 113, 7})
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes?ttl=2w", "body")

      assert response(conn, 400) == "ttl cannot exceed 7 days\n"
    end

    test "rate limits paste counts by client IP", %{conn: conn} do
      ip = {203, 0, 113, 4}

      for _ <- 1..10 do
        conn
        |> recycle()
        |> put_remote_ip(ip)
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes", "x")
        |> response(201)
      end

      conn =
        conn
        |> recycle()
        |> put_remote_ip(ip)
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes", "x")

      assert response(conn, 429) == "rate limit exceeded, try again later\n"
      assert [_retry_after] = get_resp_header(conn, "retry-after")
    end

    test "rate limits short root uploads by client IP", %{conn: conn} do
      ip = {203, 0, 113, 9}

      for _ <- 1..10 do
        conn
        |> recycle()
        |> put_remote_ip(ip)
        |> put_req_header("content-type", "text/plain")
        |> put(~p"/", "x")
        |> response(201)
      end

      conn =
        conn
        |> recycle()
        |> put_remote_ip(ip)
        |> put_req_header("content-type", "text/plain")
        |> put(~p"/", "x")

      assert response(conn, 429) == "rate limit exceeded, try again later\n"
    end

    test "rate limits uploaded bytes by client IP", %{conn: conn} do
      ip = {203, 0, 113, 5}

      conn
      |> put_remote_ip(ip)
      |> put_req_header("content-type", "text/plain")
      |> post(~p"/api/pastes", "123456789012345678901234567890")
      |> response(201)

      conn =
        conn
        |> recycle()
        |> put_remote_ip(ip)
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes", "12345678901234567890")

      assert response(conn, 429) == "rate limit exceeded, try again later\n"
    end
  end

  describe "client IP detection" do
    test "formats IPv4 and IPv6 remote addresses", %{conn: conn} do
      assert conn
             |> put_remote_ip({192, 0, 2, 10})
             |> SpitWeb.Plugs.RateLimitPasteUploads.client_ip() ==
               "192.0.2.10"

      assert conn
             |> put_remote_ip({8193, 3512, 0, 0, 0, 0, 0, 1})
             |> SpitWeb.Plugs.RateLimitPasteUploads.client_ip() == "2001:db8::1"
    end
  end

  describe "GET /p/:slug" do
    test "renders active pastes", %{conn: conn} do
      {:ok, paste} =
        Pastes.create_paste(%{
          body: "render me",
          content_type: "text/plain",
          expires_at: Pastes.expires_at_from_ttl("1d")
        })

      conn = get(conn, ~p"/p/#{paste.slug}")

      assert html_response(conn, 200) =~ "render me"
      assert html_response(conn, 200) =~ "/p/#{paste.slug}"
      refute html_response(conn, 200) =~ "Content type:"
      assert html_response(conn, 200) =~ "/raw/#{paste.slug}"
      assert html_response(conn, 200) =~ "/download/#{paste.slug}"
    end

    test "renders a 404 page for expired pastes", %{conn: conn} do
      {:ok, paste} =
        Pastes.create_paste(%{
          body: "expired",
          content_type: "text/plain",
          expires_at: DateTime.utc_now(:second) |> DateTime.add(-60, :second)
        })

      conn = get(conn, ~p"/p/#{paste.slug}")

      assert html_response(conn, 404) =~ "Paste not found"
      assert html_response(conn, 404) =~ "This link is invalid, expired"
    end
  end

  describe "GET /raw/:slug" do
    test "returns the paste body", %{conn: conn} do
      {:ok, paste} =
        Pastes.create_paste(%{
          body: "raw output",
          content_type: "text/plain",
          expires_at: nil
        })

      conn = get(conn, ~p"/raw/#{paste.slug}")

      assert response(conn, 200) == "raw output"
    end

    test "serves raw output as browser-displayable text", %{conn: conn} do
      {:ok, paste} =
        Pastes.create_paste(%{
          body: "curl default content type",
          content_type: "application/x-www-form-urlencoded",
          expires_at: nil
        })

      conn = get(conn, ~p"/raw/#{paste.slug}")

      assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
    end
  end

  describe "GET /download/:slug" do
    test "downloads the paste body as an attachment", %{conn: conn} do
      {:ok, paste} =
        Pastes.create_paste(%{
          body: "download output",
          content_type: "text/plain",
          expires_at: nil
        })

      conn = get(conn, ~p"/download/#{paste.slug}")

      assert response(conn, 200) == "download output"

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="#{paste.slug}.txt")
             ]
    end
  end

  defp put_remote_ip(conn, ip), do: %{conn | remote_ip: ip}
end
