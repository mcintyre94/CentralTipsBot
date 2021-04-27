defmodule Centraltipsbot.Wallet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "wallets" do
    field :email, :string
    field :source, :string
    field :source_id, :string
    field :confirmed, :boolean

    timestamps()
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [:source, :source_id, :email, :confirmed])
    |> validate_required([:source, :source_id, :email, :confirmed])
  end
end
