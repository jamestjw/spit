defmodule Spit.Repo.Migrations.AddEncryptedToPastes do
  use Ecto.Migration

  def change do
    alter table(:pastes) do
      add :encrypted, :boolean, default: false, null: false
    end
  end
end
