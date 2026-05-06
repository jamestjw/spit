defmodule SpitWeb.PageController do
  use SpitWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def spit_script(conn, _params) do
    serve_script(conn, "spit.sh")
  end

  def install_script(conn, _params) do
    serve_script(conn, "install.sh")
  end

  defp serve_script(conn, filename) do
    path = Application.app_dir(:spit, "priv/scripts/#{filename}")
    content = File.read!(path)
    url = SpitWeb.Endpoint.url()

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, String.replace(content, "{{SPIT_URL}}", url))
  end
end
