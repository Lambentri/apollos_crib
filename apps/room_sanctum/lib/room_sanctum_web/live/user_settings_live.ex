defmodule RoomSanctumWeb.UserSettingsLive do
  use RoomSanctumWeb, :live_view

  alias RoomSanctum.Accounts
  alias RoomSanctumWeb.ThemePicker

  def render(assigns) do
    ~H"""
    <div class="hero min-h-screen bg-base-200">
      <div class="hero-content w-full max-w-4xl">
        <div class="w-full">
          <div class="text-center mb-8">
            <h1 class="text-4xl font-bold text-base-content">Account Settings</h1>
            <p class="text-base-content/70 mt-2">Manage your account preferences and security</p>
          </div>

          <div class="space-y-8">
            <!-- Theme Picker Section -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title text-primary mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zM21 5H9M21 9H9M21 13H9M21 17H9"></path>
                  </svg>
                  Theme Preferences
                </h2>
                <ThemePicker.theme_picker />
              </div>
            </div>

            <!-- Email Settings -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title text-primary mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207"></path>
                  </svg>
                  Email Address
                </h2>
                <p class="text-base-content/70 mb-4">Update your email address. You'll need to verify the new email address.</p>
                
                <.simple_form
                  for={@email_form}
                  id="email_form"
                  phx-submit="update_email"
                  phx-change="validate_email"
                  class="space-y-4"
                >
                  <div class="form-control w-full">
                    <label class="label">
                      <span class="label-text font-medium">Email Address</span>
                    </label>
                    <.input 
                      field={@email_form[:email]} 
                      type="email" 
                      required 
                      class="input input-bordered w-full focus:input-primary"
                      placeholder="Enter your email address"
                    />
                  </div>
                  
                  <div class="form-control w-full">
                    <label class="label">
                      <span class="label-text font-medium">Current Password</span>
                      <span class="label-text-alt text-base-content/50">Required for security</span>
                    </label>
                    <.input
                      field={@email_form[:current_password]}
                      name="current_password"
                      id="current_password_for_email"
                      type="password"
                      value={@email_form_current_password}
                      required
                      class="input input-bordered w-full focus:input-primary"
                      placeholder="Enter your current password"
                    />
                  </div>
                  
                  <div class="card-actions justify-end">
                    <.button phx-disable-with="Updating..." class="btn btn-primary">
                      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                      </svg>
                      Update Email
                    </.button>
                  </div>
                </.simple_form>
              </div>
            </div>

            <!-- Password Settings -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title text-primary mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"></path>
                  </svg>
                  Password Security
                </h2>
                <p class="text-base-content/70 mb-4">Change your password to keep your account secure.</p>
                
                <.simple_form
                  for={@password_form}
                  id="password_form"
                  action={~p"/users/log_in?_action=password_updated"}
                  method="post"
                  phx-change="validate_password"
                  phx-submit="update_password"
                  phx-trigger-action={@trigger_submit}
                  class="space-y-4"
                >
                  <.input
                    field={@password_form[:email]}
                    type="hidden"
                    id="hidden_user_email"
                    value={@current_email}
                  />
                  
                  <div class="form-control w-full">
                    <label class="label">
                      <span class="label-text font-medium">New Password</span>
                      <span class="label-text-alt text-base-content/50">At least 8 characters</span>
                    </label>
                    <.input 
                      field={@password_form[:password]} 
                      type="password" 
                      required 
                      class="input input-bordered w-full focus:input-primary"
                      placeholder="Enter your new password"
                    />
                  </div>
                  
                  <div class="form-control w-full">
                    <label class="label">
                      <span class="label-text font-medium">Confirm New Password</span>
                    </label>
                    <.input
                      field={@password_form[:password_confirmation]}
                      type="password"
                      class="input input-bordered w-full focus:input-primary"
                      placeholder="Confirm your new password"
                    />
                  </div>
                  
                  <div class="form-control w-full">
                    <label class="label">
                      <span class="label-text font-medium">Current Password</span>
                      <span class="label-text-alt text-base-content/50">Required for security</span>
                    </label>
                    <.input
                      field={@password_form[:current_password]}
                      name="current_password"
                      type="password"
                      id="current_password_for_password"
                      value={@current_password}
                      required
                      class="input input-bordered w-full focus:input-primary"
                      placeholder="Enter your current password"
                    />
                  </div>
                  
                  <div class="card-actions justify-end">
                    <.button phx-disable-with="Updating..." class="btn btn-primary">
                      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"></path>
                      </svg>
                      Change Password
                    </.button>
                  </div>
                </.simple_form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)
    current_theme = get_current_theme(session)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:current_theme, current_theme)

    {:ok, socket}
  end

  defp get_current_theme(session) do
    Map.get(session, "theme", "lofi")
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("change_theme", %{"theme" => theme}, socket) do
    socket = 
      socket
      |> assign(:current_theme, theme)
      |> put_flash(:info, "Theme updated successfully!")
    
    {:noreply, socket}
  end
end
