defmodule SpitWeb.PasteControllerTest do
  use SpitWeb.ConnCase, async: true

  alias Spit.Pastes

  describe "POST /api/pastes" do
    test "accepts raw curl-style request bodies and returns a browser URL", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/api/pastes", "line one\nline two\n")

      assert response(conn, 201) =~ ~r|http://localhost:4000/p/[A-Za-z0-9_-]{8}\n|
    end

    test "still accepts explicit text/plain request bodies", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes", "plain text body\n")

      assert response(conn, 201) =~ ~r|http://localhost:4000/p/[A-Za-z0-9_-]{8}\n|
    end

    test "rejects empty bodies", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/pastes", "   \n")

      assert response(conn, 400) == "paste body cannot be empty\n"
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
      refute html_response(conn, 200) =~ "/p/#{paste.slug}"
      refute html_response(conn, 200) =~ "Content type:"
      assert html_response(conn, 200) =~ "/raw/#{paste.slug}"
      assert html_response(conn, 200) =~ "/download/#{paste.slug}"
    end

    test "returns 404 for expired pastes", %{conn: conn} do
      {:ok, paste} =
        Pastes.create_paste(%{
          body: "expired",
          content_type: "text/plain",
          expires_at: DateTime.utc_now(:second) |> DateTime.add(-60, :second)
        })

      conn = get(conn, ~p"/p/#{paste.slug}")

      assert response(conn, 404) == "paste not found"
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
end
