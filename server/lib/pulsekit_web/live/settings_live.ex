defmodule PulsekitWeb.SettingsLive do
  use PulsekitWeb, :live_view

  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:current_path, "/settings")
      |> LiveHelpers.assign_organization_context(params, session)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div>
          <h1 class="text-2xl font-bold">Settings</h1>
          <p class="text-base-content/60 mt-1">Configure your PulseKit instance</p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- General Settings --%>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">
                <.icon name="hero-cog-6-tooth" class="w-5 h-5" />
                General
              </h2>

              <div class="space-y-4">
                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-4">
                    <input type="checkbox" class="toggle toggle-primary" checked />
                    <div>
                      <span class="label-text font-medium">Real-time Updates</span>
                      <p class="text-sm text-base-content/60">
                        Automatically refresh events in real-time
                      </p>
                    </div>
                  </label>
                </div>

                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-4">
                    <input type="checkbox" class="toggle toggle-primary" checked />
                    <div>
                      <span class="label-text font-medium">Desktop Notifications</span>
                      <p class="text-sm text-base-content/60">
                        Show browser notifications for new errors
                      </p>
                    </div>
                  </label>
                </div>
              </div>
            </div>
          </div>

          <%!-- Data Retention --%>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">
                <.icon name="hero-clock" class="w-5 h-5" />
                Data Retention
              </h2>

              <div class="space-y-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Keep events for</span>
                  </label>
                  <select class="select select-bordered w-full">
                    <option value="7">7 days</option>
                    <option value="30" selected>30 days</option>
                    <option value="90">90 days</option>
                    <option value="365">1 year</option>
                    <option value="0">Forever</option>
                  </select>
                  <label class="label">
                    <span class="label-text-alt text-base-content/60">
                      Older events will be automatically deleted
                    </span>
                  </label>
                </div>
              </div>
            </div>
          </div>

          <%!-- API Information --%>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">
                <.icon name="hero-code-bracket" class="w-5 h-5" />
                API Information
              </h2>

              <div class="space-y-4">
                <div>
                  <label class="text-sm text-base-content/60">API Endpoint</label>
                  <div class="mt-1 flex items-center gap-2">
                    <code class="flex-1 bg-base-200 px-3 py-2 rounded-lg text-sm font-mono">
                      {endpoint_url()}/api/v1
                    </code>
                    <button
                      type="button"
                      class="btn btn-ghost btn-sm"
                      onclick={"navigator.clipboard.writeText('#{endpoint_url()}/api/v1')"}
                    >
                      <.icon name="hero-clipboard" class="w-4 h-4" />
                    </button>
                  </div>
                </div>

                <div>
                  <label class="text-sm text-base-content/60">Version</label>
                  <p class="mt-1 font-mono">v1.0.0</p>
                </div>
              </div>
            </div>
          </div>

          <%!-- About --%>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">
                <.icon name="hero-information-circle" class="w-5 h-5" />
                About PulseKit
              </h2>

              <div class="space-y-4">
                <p class="text-base-content/70">
                  PulseKit is an open-source observability platform for tracking errors and events in your applications.
                </p>

                <div class="flex flex-wrap gap-2">
                  <a
                    href="https://github.com/pulsekit/pulsekit"
                    target="_blank"
                    class="btn btn-outline btn-sm"
                  >
                    <.icon name="hero-code-bracket" class="w-4 h-4" />
                    GitHub
                  </a>
                  <a
                    href="https://pulsekit.dev/docs"
                    target="_blank"
                    class="btn btn-outline btn-sm"
                  >
                    <.icon name="hero-book-open" class="w-4 h-4" />
                    Documentation
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp endpoint_url do
    PulsekitWeb.Endpoint.url()
  end
end
