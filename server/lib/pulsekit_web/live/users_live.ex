defmodule PulsekitWeb.UsersLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Accounts
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Users")
      |> assign(:current_path, "/users")
      |> LiveHelpers.assign_organization_context(params, session)
      |> load_users()
      |> assign(:show_invite_modal, false)
      |> assign(:invite_form, to_form(%{"email" => "", "password" => ""}, as: :user))
      |> assign(:invite_error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_invite_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_invite_modal, true)
     |> assign(:invite_form, to_form(%{"email" => "", "password" => ""}, as: :user))
     |> assign(:invite_error, nil)}
  end

  @impl true
  def handle_event("hide_invite_modal", _params, socket) do
    {:noreply, assign(socket, show_invite_modal: false)}
  end

  @impl true
  def handle_event("validate_invite", %{"user" => params}, socket) do
    form = to_form(params, as: :user)
    {:noreply, assign(socket, invite_form: form, invite_error: nil)}
  end

  @impl true
  def handle_event("create_user", %{"user" => params}, socket) do
    case Accounts.create_user(params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User invited successfully!")
         |> assign(:show_invite_modal, false)
         |> load_users()}

      {:error, changeset} ->
        error = format_changeset_errors(changeset)
        {:noreply, assign(socket, invite_error: error)}
    end
  end

  @impl true
  def handle_event("delete_user", %{"id" => id}, socket) do
    case Accounts.get_user(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "User not found.")}

      user ->
        case Accounts.delete_user(user) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "User deleted successfully.")
             |> load_users()}

          {:error, :cannot_delete_master} ->
            {:noreply, put_flash(socket, :error, "Cannot delete the master user.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete user.")}
        end
    end
  end

  defp load_users(socket) do
    users = Accounts.list_users()
    assign(socket, :users, users)
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{Phoenix.Naming.humanize(field)} #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join(". ")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-8">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-base-content tracking-tight">Users</h1>
            <p class="text-base-content/60 mt-1">Manage user access to PulseKit</p>
          </div>
          <button
            phx-click="show_invite_modal"
            class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-primary text-primary-content font-medium shadow-sm hover:bg-primary/90 transition-colors duration-150"
          >
            <.icon name="hero-user-plus" class="w-5 h-5" />
            Invite User
          </button>
        </div>

        <%!-- Users table --%>
        <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
          <table class="w-full">
            <thead class="bg-base-200/50">
              <tr>
                <th class="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">User</th>
                <th class="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">Role</th>
                <th class="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">Created</th>
                <th class="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wider text-base-content/60">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-base-200">
              <%= for user <- @users do %>
                <tr class="hover:bg-base-200/30 transition-colors duration-100">
                  <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                        <.icon name="hero-user" class="w-5 h-5 text-primary" />
                      </div>
                      <div>
                        <p class="font-medium text-base-content">{user.email}</p>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <%= if user.is_master do %>
                      <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-warning/10 text-warning">
                        <.icon name="hero-star-solid" class="w-3.5 h-3.5" />
                        Master
                      </span>
                    <% else %>
                      <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-base-200 text-base-content/70">
                        <.icon name="hero-user" class="w-3.5 h-3.5" />
                        Member
                      </span>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 text-sm text-base-content/60">
                    {Calendar.strftime(user.inserted_at, "%b %d, %Y")}
                  </td>
                  <td class="px-6 py-4 text-right">
                    <%= if not user.is_master do %>
                      <button
                        phx-click="delete_user"
                        phx-value-id={user.id}
                        data-confirm="Are you sure you want to delete this user?"
                        class="p-2 rounded-lg text-error/70 hover:text-error hover:bg-error/10 transition-colors duration-150"
                        title="Delete user"
                      >
                        <.icon name="hero-trash" class="w-5 h-5" />
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Invite User Modal --%>
      <div
        :if={@show_invite_modal}
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
        phx-window-keydown="hide_invite_modal"
        phx-key="escape"
      >
        <%!-- Backdrop --%>
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" phx-click="hide_invite_modal" />

        <%!-- Modal content --%>
        <div class="relative w-full max-w-md bg-base-100 rounded-2xl shadow-2xl border border-base-300">
          <div class="flex items-center justify-between px-6 py-4 border-b border-base-200">
            <h2 class="text-lg font-semibold text-base-content">Invite New User</h2>
            <button
              phx-click="hide_invite_modal"
              class="p-2 rounded-lg hover:bg-base-200 transition-colors duration-150"
            >
              <.icon name="hero-x-mark" class="w-5 h-5 text-base-content/60" />
            </button>
          </div>

          <.form
            for={@invite_form}
            id="invite-form"
            phx-change="validate_invite"
            phx-submit="create_user"
            class="p-6 space-y-5"
          >
            <%!-- Error message --%>
            <div :if={@invite_error} class="p-4 rounded-lg bg-error/10 border border-error/20">
              <div class="flex items-center gap-3">
                <.icon name="hero-exclamation-circle" class="w-5 h-5 text-error flex-shrink-0" />
                <p class="text-sm text-error font-medium">{@invite_error}</p>
              </div>
            </div>

            <div>
              <label for="invite_email" class="block text-sm font-medium text-base-content mb-2">
                Email address
              </label>
              <input
                type="email"
                name="user[email]"
                id="invite_email"
                value={@invite_form[:email].value}
                required
                class="block w-full px-4 py-3 rounded-xl border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                placeholder="user@example.com"
              />
            </div>

            <div>
              <label for="invite_password" class="block text-sm font-medium text-base-content mb-2">
                Initial Password
              </label>
              <input
                type="password"
                name="user[password]"
                id="invite_password"
                value={@invite_form[:password].value}
                required
                class="block w-full px-4 py-3 rounded-xl border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                placeholder="Min 8 characters"
              />
              <p class="mt-1.5 text-xs text-base-content/50">
                Share this password securely with the user
              </p>
            </div>

            <div class="flex items-center gap-3 pt-2">
              <button
                type="button"
                phx-click="hide_invite_modal"
                class="flex-1 px-4 py-2.5 rounded-lg border border-base-300 text-base-content font-medium hover:bg-base-200 transition-colors duration-150"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="flex-1 px-4 py-2.5 rounded-lg bg-primary text-primary-content font-medium shadow-sm hover:bg-primary/90 transition-colors duration-150"
              >
                Create User
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
