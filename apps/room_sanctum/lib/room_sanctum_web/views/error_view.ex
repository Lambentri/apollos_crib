defmodule RoomSanctumWeb.ErrorView do
  use RoomSanctumWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  # By default, Phoenix returns the status message from the template name. For
  # example, "404.html" becomes "Not Found".
  #
  # render/2 rather than template_not_found/2: the latter was Phoenix 1.6's
  # fallback and nothing calls it here, so every error this app raised failed
  # again while rendering the page that was meant to explain it -- a mistyped
  # URL answered 500 rather than 404.
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
