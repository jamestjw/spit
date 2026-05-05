defmodule Spit.Repo do
  use Ecto.Repo,
    otp_app: :spit,
    adapter: Ecto.Adapters.Postgres
end
