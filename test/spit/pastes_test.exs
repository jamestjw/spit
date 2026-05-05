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
end
