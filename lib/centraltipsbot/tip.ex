defmodule Centraltipsbot.Tip do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tips" do
    field :from_source, :string
    field :from_source_id, :string
    field :memo, :string
    field :paid, :boolean, default: false
    field :quantity, :decimal
    field :to_source, :string
    field :to_source_id, :string

    timestamps()
  end

  @doc false
  def changeset(tip, attrs) do
    tip
    |> cast(attrs, [:from_source, :from_source_id, :to_source, :to_source_id, :memo, :quantity, :paid])
    |> validate_required([:from_source, :from_source_id, :to_source, :to_source_id, :memo, :quantity, :paid])
  end
end
