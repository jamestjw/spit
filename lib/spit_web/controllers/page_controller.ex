defmodule SpitWeb.PageController do
  use SpitWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
