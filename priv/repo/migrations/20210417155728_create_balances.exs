defmodule Centraltipsbot.Repo.Migrations.CreateBalances do
  use Ecto.Migration

  def change do
    create table(:balances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :string
      add :source_id, :string
      add :balance, :decimal

      timestamps()
    end

    create unique_index(:balances, [:source, :source_id], name: :unique_source_source_id)
  end
end
