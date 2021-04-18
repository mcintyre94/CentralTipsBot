defmodule Centraltipsbot.Optout do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "optouts" do
    field :source, :string
    field :source_id, :string

    timestamps()
  end

  @doc false
  def changeset(optout, attrs) do
    optout
    |> cast(attrs, [:source, :source_id])
    |> validate_required([:source, :source_id])
  end
end
