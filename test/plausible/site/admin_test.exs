defmodule Plausible.Site.AdminTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test

  setup do
    admin_user = insert(:user)
    conn = %Plug.Conn{assigns: %{current_user: admin_user}}
    transfer_action = Plausible.SiteAdmin.list_actions(conn)[:transfer_ownership][:action]

    transfer_direct_action =
      Plausible.SiteAdmin.list_actions(conn)[:transfer_ownership_direct][:action]

    {:ok,
     %{
       transfer_action: transfer_action,
       transfer_direct_action: transfer_direct_action,
       conn: conn
     }}
  end

  describe "bulk transferring site ownership" do
    test "user has to select at least one site", %{conn: conn, transfer_action: action} do
      assert action.(conn, [], %{}) == {:error, "Please select at least one site from the list"}
    end

    test "new owner must be an existing user", %{conn: conn, transfer_action: action} do
      site = insert(:site)

      assert action.(conn, [site], %{"email" => "random@email.com"}) ==
               {:error, "User could not be found"}
    end

    test "new owner can't be the same as old owner", %{conn: conn, transfer_action: action} do
      current_owner = insert(:user)

      site = insert(:site, members: [current_owner])

      assert {:error, "User is already an owner of one of the sites"} =
               action.(conn, [site], %{"email" => current_owner.email})
    end

    test "initiates ownership transfer for multiple sites in one action", %{
      conn: conn,
      transfer_action: action
    } do
      current_owner = insert(:user)
      new_owner = insert(:user)

      site1 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      site2 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      assert :ok = action.(conn, [site1, site2], %{"email" => new_owner.email})

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: "[Plausible Analytics] Request to transfer ownership of #{site1.domain}"
      )

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: "[Plausible Analytics] Request to transfer ownership of #{site2.domain}"
      )
    end
  end

  describe "bulk transferring site ownership directly" do
    test "user has to select at least one site", %{conn: conn, transfer_direct_action: action} do
      assert action.(conn, [], %{}) == {:error, "Please select at least one site from the list"}
    end

    test "new owner must be an existing user", %{conn: conn, transfer_direct_action: action} do
      site = insert(:site)

      assert action.(conn, [site], %{"email" => "random@email.com"}) ==
               {:error, "User could not be found"}
    end

    test "new owner can't be the same as old owner", %{conn: conn, transfer_direct_action: action} do
      current_owner = insert(:user)

      site = insert(:site, members: [current_owner])

      assert {:error, "User is already an owner of one of the sites"} =
               action.(conn, [site], %{"email" => current_owner.email})
    end

    @tag :ee_only
    test "new owner's plan must accommodate the transferred site", %{
      conn: conn,
      transfer_direct_action: action
    } do
      today = Date.utc_today()
      current_owner = insert(:user)

      new_owner =
        insert(:user,
          subscription:
            build(:growth_subscription,
              last_bill_date: Timex.shift(today, days: -5)
            )
        )

      # fills the site limit quota
      insert_list(10, :site, members: [new_owner])

      site = insert(:site, members: [current_owner])

      assert {:error, "Plan limits exceeded" <> _} =
               action.(conn, [site], %{"email" => new_owner.email})
    end

    test "executes ownership transfer for multiple sites in one action", %{
      conn: conn,
      transfer_direct_action: action
    } do
      today = Date.utc_today()
      current_owner = insert(:user)

      new_owner =
        insert(:user,
          subscription: build(:subscription, last_bill_date: Timex.shift(today, days: -5))
        )

      site1 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      site2 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      assert :ok = action.(conn, [site1, site2], %{"email" => new_owner.email})
    end
  end
end
