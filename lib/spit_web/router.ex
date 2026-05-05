defmodule SpitWeb.Router do
  use SpitWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SpitWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug SpitWeb.Plugs.RateLimitPasteUploads
  end

  scope "/", SpitWeb do
    pipe_through :api

    put "/", PasteController, :create
  end

  scope "/", SpitWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/p/:slug", PasteController, :show
    get "/raw/:slug", PasteController, :raw
    get "/download/:slug", PasteController, :download
  end

  scope "/api", SpitWeb do
    pipe_through :api

    post "/pastes", PasteController, :create
  end
end
