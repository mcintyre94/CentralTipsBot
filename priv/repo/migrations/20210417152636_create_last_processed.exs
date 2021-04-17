defmodule Centraltipsbot.Repo.Migrations.CreateLastProcessed do
  use Ecto.Migration

  def change do
    create table(:last_processed, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :last_processed, :map

      timestamps()
    end

  end
end
