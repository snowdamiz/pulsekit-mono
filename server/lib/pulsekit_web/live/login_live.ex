defmodule PulsekitWeb.LoginLive do
  use PulsekitWeb, :live_view

  require Logger
  alias Pulsekit.Accounts

  @impl true
  def mount(_params, session, socket) do
    # If already logged in, redirect to home
    if session["user_id"] do
      {:ok, push_navigate(socket, to: "/")}
    else
      socket =
        socket
        |> assign(:page_title, "Sign In")
        |> assign(:email, "")
        |> assign(:error, nil)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("login", %{"email" => email, "password" => password}, socket) do
    Logger.info("Login attempt for: #{email}")

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        Logger.info("Login successful for: #{email}")
        {:noreply,
         socket
         |> put_flash(:info, "Welcome back!")
         |> redirect(to: "/auth/callback?user_id=#{user.id}")}

      {:error, reason} ->
        Logger.warning("Login failed for #{email}: #{reason}")
        {:noreply,
         socket
         |> assign(:email, email)
         |> assign(:error, "Invalid email or password")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex flex-col justify-center">
      <%!-- Background pattern --%>
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class="absolute -top-1/2 -right-1/4 w-[800px] h-[800px] rounded-full bg-gradient-to-br from-primary/5 to-transparent blur-3xl" />
        <div class="absolute -bottom-1/2 -left-1/4 w-[600px] h-[600px] rounded-full bg-gradient-to-tr from-secondary/5 to-transparent blur-3xl" />
      </div>

      <div class="relative sm:mx-auto sm:w-full sm:max-w-md px-4">
        <%!-- Logo and title --%>
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-primary to-primary/80 shadow-lg shadow-primary/20 mb-4">
            <.icon name="hero-bolt-solid" class="w-8 h-8 text-primary-content" />
          </div>
          <h1 class="text-3xl font-bold tracking-tight text-base-content">PulseKit</h1>
          <p class="mt-2 text-sm text-base-content/60">Sign in to your account</p>
        </div>

        <%!-- Login form card --%>
        <div class="bg-base-100 rounded-2xl shadow-xl border border-base-300 p-8">
          <form
            id="login-form"
            phx-submit="login"
            class="space-y-6"
          >
            <%!-- Error message --%>
            <div :if={@error} class="p-4 rounded-lg bg-error/10 border border-error/20">
              <div class="flex items-center gap-3">
                <.icon name="hero-exclamation-circle" class="w-5 h-5 text-error flex-shrink-0" />
                <p class="text-sm text-error font-medium">{@error}</p>
              </div>
            </div>

            <%!-- Email field --%>
            <div>
              <label for="email" class="block text-sm font-medium text-base-content mb-2">
                Email address
              </label>
              <div class="relative">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                  <.icon name="hero-envelope" class="w-5 h-5 text-base-content/40" />
                </div>
                <input
                  type="email"
                  name="email"
                  id="email"
                  value={@email}
                  required
                  autocomplete="email"
                  class="block w-full pl-11 pr-4 py-3 rounded-xl border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                  placeholder="you@example.com"
                />
              </div>
            </div>

            <%!-- Password field --%>
            <div>
              <label for="password" class="block text-sm font-medium text-base-content mb-2">
                Password
              </label>
              <div class="relative">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                  <.icon name="hero-lock-closed" class="w-5 h-5 text-base-content/40" />
                </div>
                <input
                  type="password"
                  name="password"
                  id="password"
                  required
                  autocomplete="current-password"
                  class="block w-full pl-11 pr-4 py-3 rounded-xl border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                  placeholder="Enter your password"
                />
              </div>
            </div>

            <%!-- Submit button --%>
            <button
              type="submit"
              class="w-full flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-primary text-primary-content font-semibold shadow-sm hover:bg-primary/90 focus:ring-2 focus:ring-primary/20 focus:ring-offset-2 focus:ring-offset-base-100 transition-all duration-150"
            >
              <.icon name="hero-arrow-right-end-on-rectangle" class="w-5 h-5" />
              Sign in
            </button>
          </form>
        </div>

        <%!-- Footer --%>
        <p class="mt-8 text-center text-xs text-base-content/40">
          Open-source observability platform
        </p>
      </div>

      <Layouts.flash_group flash={@flash} />
    </div>
    """
  end
end
