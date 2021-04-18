defmodule Centraltipsbot.Repo.Migrations.CreateOptouts do
  use Ecto.Migration

  def change do
    create table(:optouts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :string
      add :source_id, :string

      timestamps()
    end

    create unique_index(:optouts, [:source, :source_id], name: :optouts_unique_source_source_id)
  end
end
