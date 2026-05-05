defmodule Spit.Repo.Migrations.CreatePastes do
  use Ecto.Migration

  def change do
    create table(:pastes) do
      add :slug, :string, null: false
      add :body, :text, null: false
      add :content_type, :string, null: false, default: "text/plain"
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pastes, [:slug])
    create index(:pastes, [:expires_at])
  end
end
