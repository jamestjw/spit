defmodule Spit.PastesTest do
  use Spit.DataCase, async: true

  alias Spit.Pastes

  describe "create_paste/1" do
    test "creates a paste with a generated slug" do
      assert {:ok, paste} =
               Pastes.create_paste(%{
                 body: "hello from test",
                 content_type: "text/plain",
                 expires_at: Pastes.expires_at_from_ttl("1d")
               })

      assert byte_size(paste.slug) == 8
      assert paste.body == "hello from test"
    end
  end

  describe "get_active_paste_by_slug/1" do
    test "returns nil for expired pastes" do
      assert {:ok, paste} =
               Pastes.create_paste(%{
                 body: "too late",
                 content_type: "text/plain",
                 expires_at: DateTime.utc_now(:second) |> DateTime.add(-60, :second)
               })

      assert Pastes.get_active_paste_by_slug(paste.slug) == nil
    end
  end

  describe "ttl_expires_at/1" do
    test "defaults to one day" do
      assert {:ok, expires_at} = Pastes.ttl_expires_at(nil)

      assert DateTime.diff(expires_at, DateTime.utc_now(:second), :second) in 86_399..86_400
    end

    test "allows up to one week" do
      assert {:ok, expires_at} = Pastes.ttl_expires_at("7d")

      assert DateTime.diff(expires_at, DateTime.utc_now(:second), :second) in 604_799..604_800
    end

    test "rejects never and values over one week" do
      assert Pastes.ttl_expires_at("never") == {:error, "ttl=never is not allowed"}
      assert Pastes.ttl_expires_at("2w") == {:error, "ttl cannot exceed 7 days"}
    end
  end
end
