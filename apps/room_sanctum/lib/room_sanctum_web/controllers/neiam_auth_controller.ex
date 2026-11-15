defmodule RoomSanctumWeb.NeiamAuthController do
  use NeiamAuth.Controller, adapter: RoomSanctum.NeiamAuthAdapter
end
