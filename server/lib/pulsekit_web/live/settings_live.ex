defmodule PulsekitWeb.SettingsLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Settings
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(params, session, socket) do
    retention_days = Settings.log_retention_days()

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:current_path, "/settings")
      |> assign(:retention_days, retention_days)
      |> LiveHelpers.assign_organization_context(params, session)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_retention", %{"retention" => days}, socket) do
    days = String.to_integer(days)
    Settings.set_log_retention_days(days)

    {:noreply,
     socket
     |> assign(:retention_days, days)
     |> put_flash(:info, "Log retention setting updated successfully.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-8">
        <%!-- Header --%>
        <div>
          <h1 class="text-2xl font-bold text-base-content tracking-tight">Settings</h1>
          <p class="text-base-content/60 mt-1">Configure your PulseKit instance</p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- General Settings --%>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
            <div class="flex items-center gap-3 px-5 py-4 border-b border-base-200 bg-base-200/30">
              <div class="p-2 rounded-lg bg-primary/10">
                <.icon name="hero-cog-6-tooth" class="w-4 h-4 text-primary" />
              </div>
              <h2 class="font-semibold text-base-content">General</h2>
            </div>

            <div class="p-5 space-y-5">
              <.setting_toggle
                title="Real-time Updates"
                description="Automatically refresh events in real-time"
                checked={true}
              />

              <.setting_toggle
                title="Desktop Notifications"
                description="Show browser notifications for new errors"
                checked={true}
              />
            </div>
          </div>

          <%!-- Data Retention --%>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
            <div class="flex items-center gap-3 px-5 py-4 border-b border-base-200 bg-base-200/30">
              <div class="p-2 rounded-lg bg-info/10">
                <.icon name="hero-clock" class="w-4 h-4 text-info" />
              </div>
              <h2 class="font-semibold text-base-content">Data Retention</h2>
            </div>

            <div class="p-5">
              <div>
                <label class="block text-sm font-medium text-base-content mb-1.5">
                  Keep events for
                </label>
                <select
                  name="retention"
                  phx-change="update_retention"
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150 cursor-pointer"
                >
                  <option value="7" selected={@retention_days == 7}>7 days</option>
                  <option value="30" selected={@retention_days == 30}>30 days</option>
                  <option value="90" selected={@retention_days == 90}>90 days</option>
                  <option value="365" selected={@retention_days == 365}>1 year</option>
                  <option value="0" selected={@retention_days == 0}>Forever</option>
                </select>
                <p class="mt-2 text-xs text-base-content/50">
                  Older events will be automatically deleted
                </p>
              </div>
            </div>
          </div>

          <%!-- API Information --%>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
            <div class="flex items-center gap-3 px-5 py-4 border-b border-base-200 bg-base-200/30">
              <div class="p-2 rounded-lg bg-warning/10">
                <.icon name="hero-code-bracket" class="w-4 h-4 text-warning" />
              </div>
              <h2 class="font-semibold text-base-content">API Information</h2>
            </div>

            <div class="p-5 space-y-5">
              <div>
                <label class="block text-xs font-medium text-base-content/50 uppercase tracking-wider mb-2">
                  API Endpoint
                </label>
                <div class="flex items-center gap-2">
                  <div class="flex-1 px-3 py-2.5 rounded-lg bg-base-200/50 border border-base-300 font-mono text-sm text-base-content overflow-x-auto">
                    {endpoint_url()}/api/v1
                  </div>
                  <button
                    type="button"
                    class="flex-shrink-0 p-2.5 rounded-lg border border-base-300 bg-base-100 hover:bg-base-200 transition-colors duration-150"
                    onclick={"navigator.clipboard.writeText('#{endpoint_url()}/api/v1')"}
                    title="Copy to clipboard"
                  >
                    <.icon name="hero-clipboard" class="w-4 h-4 text-base-content/70" />
                  </button>
                </div>
              </div>

              <div>
                <label class="block text-xs font-medium text-base-content/50 uppercase tracking-wider mb-2">
                  Version
                </label>
                <p class="font-mono text-base-content">v1.0.0</p>
              </div>
            </div>
          </div>

          <%!-- About --%>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
            <div class="flex items-center gap-3 px-5 py-4 border-b border-base-200 bg-base-200/30">
              <div class="p-2 rounded-lg bg-success/10">
                <.icon name="hero-information-circle" class="w-4 h-4 text-success" />
              </div>
              <h2 class="font-semibold text-base-content">About PulseKit</h2>
            </div>

            <div class="p-5 space-y-5">
              <p class="text-sm text-base-content/70 leading-relaxed">
                PulseKit is an open-source observability platform for tracking errors and events in your applications. Built with Elixir and Phoenix.
              </p>

              <div class="flex flex-wrap gap-2">
                <a
                  href="https://github.com/pulsekit/pulsekit"
                  target="_blank"
                  class="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-base-300 bg-base-100 text-sm font-medium text-base-content hover:bg-base-200 transition-colors duration-150"
                >
                  <.icon name="hero-code-bracket" class="w-4 h-4" />
                  GitHub
                </a>
                <a
                  href="https://pulsekit.dev/docs"
                  target="_blank"
                  class="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-base-300 bg-base-100 text-sm font-medium text-base-content hover:bg-base-200 transition-colors duration-150"
                >
                  <.icon name="hero-book-open" class="w-4 h-4" />
                  Documentation
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :checked, :boolean, default: false

  defp setting_toggle(assigns) do
    ~H"""
    <label class="flex items-start gap-4 cursor-pointer group">
      <div class="relative mt-0.5">
        <input
          type="checkbox"
          checked={@checked}
          class="peer sr-only"
        />
        <div class={[
          "w-11 h-6 rounded-full transition-colors duration-200",
          "bg-base-300 peer-checked:bg-primary"
        ]} />
        <div class={[
          "absolute left-0.5 top-0.5 w-5 h-5 rounded-full bg-white shadow-sm transition-transform duration-200",
          "peer-checked:translate-x-5"
        ]} />
      </div>
      <div class="flex-1">
        <span class="block text-sm font-medium text-base-content group-hover:text-primary transition-colors duration-150">
          {@title}
        </span>
        <span class="block text-xs text-base-content/50 mt-0.5">
          {@description}
        </span>
      </div>
    </label>
    """
  end

  defp endpoint_url do
    PulsekitWeb.Endpoint.url()
  end
end
