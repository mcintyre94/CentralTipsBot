defmodule Centraltipsbot.Repo.Migrations.CreateTips do
  use Ecto.Migration

  def change do
    create table(:tips, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :from_source, :string
      add :from_source_id, :string
      add :to_source, :string
      add :to_source_id, :string
      add :memo, :string
      add :quantity, :decimal
      add :paid, :boolean, default: false, null: false

      timestamps()
    end

    create index(:tips, [:inserted_at, :paid])
  end
end
