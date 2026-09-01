defmodule RoomHermesWeb.ErrorView do
  use RoomHermesWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  # By default, Phoenix returns the status message from the template name. For
  # example, "404.html" becomes "Not Found".
  #
  # render/2 rather than template_not_found/2, which was Phoenix 1.6's fallback
  # and is not on the path the endpoint takes -- see RoomSanctumWeb.ErrorView.
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
