defmodule Centraltipsbot.Repo.Migrations.CreateWallets do
  use Ecto.Migration

  def change do
    create table(:wallets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :string
      add :source_id, :string
      add :email, :string

      timestamps()
    end

    create unique_index(:wallets, [:source, :source_id], name: :wallets_unique_source_source_id)
  end
end
