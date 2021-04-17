defmodule Centraltipsbot.LastProcessed do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "last_processed" do
    field :last_processed, :map
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(last_processed, attrs) do
    last_processed
    |> cast(attrs, [:name, :last_processed])
    |> validate_required([:name, :last_processed])
  end
end
