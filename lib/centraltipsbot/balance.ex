defmodule Centraltipsbot.Balance do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "balances" do
    field :balance, :decimal
    field :source, :string
    field :source_id, :string

    timestamps()
  end

  @doc false
  def changeset(balance, attrs) do
    balance
    |> cast(attrs, [:source, :source_id, :balance])
    |> validate_required([:source, :source_id, :balance])
  end
end
