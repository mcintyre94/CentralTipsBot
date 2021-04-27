defmodule Centraltipsbot.Repo.Migrations.WalletsAddConfirm do
  use Ecto.Migration

  def change do
    alter table(:wallets) do
      add :confirmed, :boolean
    end
  end
end
