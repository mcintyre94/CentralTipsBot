defmodule Centraltipsbot.Wallet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "wallets" do
    field :email, :string
    field :source, :string
    field :source_id, :string

    timestamps()
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [:source, :source_id, :email])
    |> validate_required([:source, :source_id, :email])
  end
end
