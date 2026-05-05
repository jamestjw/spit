defmodule Spit.Pastes.Paste do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pastes" do
    field :slug, :string
    field :body, :string
    field :content_type, :string, default: "text/plain"
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(paste, attrs) do
    paste
    |> cast(attrs, [:slug, :body, :content_type, :expires_at])
    |> validate_required([:slug, :body, :content_type])
    |> validate_length(:body, max: 1_000_000)
    |> validate_length(:slug, min: 6, max: 32)
    |> unique_constraint(:slug)
  end
end
