defmodule Spit.Pastes do
  import Ecto.Query, warn: false

  alias Spit.Pastes.Paste
  alias Spit.Repo

  @default_ttl_seconds 24 * 60 * 60
  @max_ttl_seconds 7 * 24 * 60 * 60

  def create_paste(attrs) do
    attrs = Map.put_new(attrs, :slug, unique_slug())

    %Paste{}
    |> Paste.changeset(attrs)
    |> Repo.insert()
  end

  def get_active_paste_by_slug(slug) do
    now = DateTime.utc_now(:second)

    Paste
    |> where([paste], paste.slug == ^slug)
    |> where([paste], is_nil(paste.expires_at) or paste.expires_at > ^now)
    |> Repo.one()
  end

  def expires_at_from_ttl(ttl) do
    case ttl_expires_at(ttl) do
      {:ok, expires_at} -> expires_at
      {:error, _message} -> default_expires_at()
    end
  end

  def ttl_expires_at(nil), do: {:ok, default_expires_at()}
  def ttl_expires_at(""), do: {:ok, default_expires_at()}

  def ttl_expires_at(ttl) when is_binary(ttl) do
    if String.downcase(String.trim(ttl)) == "never" do
      {:error, "ttl=never is not allowed"}
    else
      with {amount, unit} <- parse_ttl(ttl),
           seconds when seconds > 0 <- amount * seconds_for(unit) do
        if seconds <= @max_ttl_seconds do
          {:ok, DateTime.utc_now(:second) |> DateTime.add(seconds, :second)}
        else
          {:error, "ttl cannot exceed 7 days"}
        end
      else
        _ -> {:error, "invalid ttl"}
      end
    end
  end

  defp default_expires_at do
    DateTime.utc_now(:second) |> DateTime.add(@default_ttl_seconds, :second)
  end

  defp parse_ttl(ttl) do
    case Regex.run(~r/^([1-9][0-9]*)(m|h|d|w)$/i, String.trim(ttl)) do
      [_, amount, unit] -> {String.to_integer(amount), String.downcase(unit)}
      _ -> :error
    end
  end

  defp seconds_for("m"), do: 60
  defp seconds_for("h"), do: 60 * 60
  defp seconds_for("d"), do: 24 * 60 * 60
  defp seconds_for("w"), do: 7 * 24 * 60 * 60

  defp unique_slug do
    slug = :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)

    if Repo.get_by(Paste, slug: slug) do
      unique_slug()
    else
      slug
    end
  end
end
