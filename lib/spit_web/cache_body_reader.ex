defmodule SpitWeb.CacheBodyReader do
  @moduledoc false

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} -> {:ok, body, cache_body(conn, body)}
      {:more, body, conn} -> {:more, body, cache_body(conn, body)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cache_body(conn, body) do
    Plug.Conn.assign(conn, :raw_body, [body | conn.assigns[:raw_body] || []])
  end
end
