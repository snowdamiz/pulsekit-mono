defmodule PulsekitWeb.AlertsLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Projects
  alias Pulsekit.Alerts
  alias Pulsekit.Alerts.AlertRule
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Alerts")
      |> assign(:current_path, "/alerts")
      |> LiveHelpers.assign_organization_context(params, session)
      |> load_projects()
      |> assign(:show_modal, false)
      |> assign(:editing_rule, nil)
      |> assign(:form, to_form(Alerts.change_alert_rule(%AlertRule{})))
      |> load_alert_rules()

    {:ok, socket}
  end

  defp load_projects(socket) do
    projects =
      case socket.assigns.current_organization do
        nil -> []
        org -> Projects.list_projects_for_organization(org.id)
      end

    socket
    |> assign(:projects, projects)
    |> assign(:selected_project, List.first(projects))
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:show_modal, true)
    |> assign(:editing_rule, nil)
    |> assign(:form, to_form(Alerts.change_alert_rule(%AlertRule{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    rule = Alerts.get_alert_rule!(id)

    socket
    |> assign(:show_modal, true)
    |> assign(:editing_rule, rule)
    |> assign(:form, to_form(Alerts.change_alert_rule(rule)))
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:show_modal, false)
    |> assign(:editing_rule, nil)
  end

  defp load_alert_rules(socket) do
    case socket.assigns.selected_project do
      nil ->
        assign(socket, :alert_rules, [])

      project ->
        rules = Alerts.list_alert_rules(project.id)
        assign(socket, :alert_rules, rules)
    end
  end

  @impl true
  def handle_event("select_project", %{"id" => id}, socket) do
    project = Projects.get_project!(id)

    socket =
      socket
      |> assign(:selected_project, project)
      |> load_alert_rules()

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_alert", params, socket) do
    alert_params = %{
      name: params["name"],
      condition_type: params["condition_type"],
      condition_config: build_condition_config(params),
      webhook_url: params["webhook_url"],
      enabled: true
    }

    case Alerts.create_alert_rule(socket.assigns.selected_project.id, alert_params) do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> load_alert_rules()
         |> assign(:show_modal, false)
         |> put_flash(:info, "Alert rule created successfully")
         |> push_patch(to: "/alerts")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("update_alert", params, socket) do
    alert_params = %{
      name: params["name"],
      condition_type: params["condition_type"],
      condition_config: build_condition_config(params),
      webhook_url: params["webhook_url"]
    }

    case Alerts.update_alert_rule(socket.assigns.editing_rule, alert_params) do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> load_alert_rules()
         |> assign(:show_modal, false)
         |> put_flash(:info, "Alert rule updated successfully")
         |> push_patch(to: "/alerts")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_alert", %{"id" => id}, socket) do
    rule = Alerts.get_alert_rule!(id)

    case Alerts.toggle_alert_rule(rule) do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> load_alert_rules()
         |> put_flash(:info, "Alert rule #{if rule.enabled, do: "disabled", else: "enabled"}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle alert rule")}
    end
  end

  @impl true
  def handle_event("delete_alert", %{"id" => id}, socket) do
    rule = Alerts.get_alert_rule!(id)

    case Alerts.delete_alert_rule(rule) do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_alert_rules()
         |> put_flash(:info, "Alert rule deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete alert rule")}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, push_patch(socket, to: "/alerts")}
  end

  defp build_condition_config(params) do
    case params["condition_type"] do
      "threshold" ->
        %{
          "count" => String.to_integer(params["threshold_count"] || "10"),
          "window" => params["threshold_window"] || "5m"
        }

      "pattern_match" ->
        %{"pattern" => params["pattern"] || ""}

      _ ->
        %{}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-bold text-base-content tracking-tight">Alerts</h1>
            <p class="text-base-content/60 mt-1">Configure webhook alerts for your events</p>
          </div>

          <div class="flex items-center gap-3">
            <%= if length(@projects) > 0 do %>
              <div class="dropdown dropdown-end">
                <div
                  tabindex="0"
                  role="button"
                  class="flex items-center gap-2 px-4 py-2 rounded-lg border border-base-300 bg-base-100 hover:bg-base-200 transition-colors duration-150 cursor-pointer"
                >
                  <.icon name="hero-folder" class="w-4 h-4 text-primary" />
                  <span class="font-medium text-sm">{if @selected_project, do: @selected_project.name, else: "Select Project"}</span>
                  <.icon name="hero-chevron-down" class="w-4 h-4 text-base-content/50" />
                </div>
                <ul tabindex="0" class="dropdown-content z-[1] mt-2 p-1.5 w-56 bg-base-100 rounded-lg border border-base-300 shadow-lg">
                  <%= for project <- @projects do %>
                    <li>
                      <button
                        phx-click="select_project"
                        phx-value-id={project.id}
                        class={[
                          "flex items-center gap-2 w-full px-3 py-2 rounded-md text-sm text-left transition-colors duration-100",
                          if(@selected_project && @selected_project.id == project.id,
                            do: "bg-primary/10 text-primary font-medium",
                            else: "text-base-content hover:bg-base-200"
                          )
                        ]}
                      >
                        <.icon name="hero-folder" class="w-4 h-4" />
                        <span class="truncate">{project.name}</span>
                        <.icon :if={@selected_project && @selected_project.id == project.id} name="hero-check" class="w-4 h-4 ml-auto" />
                      </button>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>

            <%= if @selected_project do %>
              <a
                href="/alerts/new"
                class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-primary text-primary-content font-medium text-sm hover:brightness-110 transition-all duration-150 shadow-sm hover:shadow-md"
              >
                <.icon name="hero-plus" class="w-4 h-4" />
                New Alert
              </a>
            <% end %>
          </div>
        </div>

        <%= if @selected_project do %>
          <%!-- Alert Rules --%>
          <%= if length(@alert_rules) == 0 do %>
            <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm">
              <div class="flex flex-col items-center text-center py-20 px-6">
                <div class="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-6">
                  <.icon name="hero-bell-slash" class="w-10 h-10 text-primary" />
                </div>
                <h2 class="text-xl font-semibold text-base-content">No alert rules yet</h2>
                <p class="text-base-content/60 max-w-md mt-2">
                  Create alert rules to get notified via webhooks when specific events occur.
                </p>
                <a
                  href="/alerts/new"
                  class="inline-flex items-center gap-2 mt-6 px-5 py-2.5 rounded-lg bg-primary text-primary-content font-medium text-sm hover:brightness-110 transition-all duration-150 shadow-sm hover:shadow-md"
                >
                  <.icon name="hero-plus" class="w-4 h-4" />
                  Create Alert Rule
                </a>
              </div>
            </div>
          <% else %>
            <div class="space-y-4">
              <%= for rule <- @alert_rules do %>
                <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm hover:shadow-md transition-shadow duration-150 overflow-hidden">
                  <div class="p-5">
                    <div class="flex items-start justify-between gap-4">
                      <div class="flex items-start gap-4">
                        <%!-- Status Indicator --%>
                        <div class={[
                          "w-3 h-3 rounded-full mt-1.5 flex-shrink-0",
                          if(rule.enabled, do: "bg-primary shadow-sm shadow-primary/50", else: "bg-base-300")
                        ]} />
                        <div>
                          <h3 class="font-semibold text-base-content">{rule.name}</h3>
                          <p class="text-sm text-base-content/60 mt-1">
                            {format_condition(rule)}
                          </p>
                        </div>
                      </div>

                      <div class="flex items-center gap-1">
                        <button
                          phx-click="toggle_alert"
                          phx-value-id={rule.id}
                          class="p-2 rounded-lg hover:bg-base-200 transition-colors duration-150"
                          title={if rule.enabled, do: "Disable", else: "Enable"}
                        >
                          <%= if rule.enabled do %>
                            <.icon name="hero-pause" class="w-4 h-4 text-base-content/70" />
                          <% else %>
                            <.icon name="hero-play" class="w-4 h-4 text-base-content/70" />
                          <% end %>
                        </button>
                        <a
                          href={"/alerts/#{rule.id}/edit"}
                          class="p-2 rounded-lg hover:bg-base-200 transition-colors duration-150"
                          title="Edit"
                        >
                          <.icon name="hero-pencil" class="w-4 h-4 text-base-content/70" />
                        </a>
                        <button
                          phx-click="delete_alert"
                          phx-value-id={rule.id}
                          data-confirm="Are you sure you want to delete this alert rule?"
                          class="p-2 rounded-lg hover:bg-error/10 transition-colors duration-150"
                          title="Delete"
                        >
                          <.icon name="hero-trash" class="w-4 h-4 text-error" />
                        </button>
                      </div>
                    </div>

                    <div class="mt-4 pt-4 border-t border-base-200">
                      <div class="flex items-center gap-2 text-sm">
                        <.icon name="hero-link" class="w-4 h-4 text-base-content/40" />
                        <span class="text-base-content/60 truncate font-mono text-xs">{rule.webhook_url}</span>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm">
            <div class="flex flex-col items-center text-center py-20 px-6">
              <div class="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-6">
                <.icon name="hero-folder-plus" class="w-10 h-10 text-primary" />
              </div>
              <h2 class="text-xl font-semibold text-base-content">No projects yet</h2>
              <p class="text-base-content/60 max-w-md mt-2">Create a project first to configure alerts.</p>
              <a
                href="/projects/new"
                class="inline-flex items-center gap-2 mt-6 px-5 py-2.5 rounded-lg bg-primary text-primary-content font-medium text-sm hover:brightness-110 transition-all duration-150 shadow-sm hover:shadow-md"
              >
                <.icon name="hero-plus" class="w-4 h-4" />
                Create Project
              </a>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Alert Modal --%>
      <%= if @show_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <%!-- Backdrop --%>
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_modal"
          />

          <%!-- Modal --%>
          <div class="relative w-full max-w-lg mx-4 rounded-xl border border-base-300 bg-base-100 shadow-xl">
            <div class="flex items-center justify-between px-6 py-4 border-b border-base-200">
              <h3 class="text-lg font-semibold text-base-content">
                {if @editing_rule, do: "Edit Alert Rule", else: "Create Alert Rule"}
              </h3>
              <button
                phx-click="close_modal"
                class="p-1.5 rounded-lg hover:bg-base-200 transition-colors duration-150"
              >
                <.icon name="hero-x-mark" class="w-5 h-5 text-base-content/50" />
              </button>
            </div>

            <form phx-submit={if @editing_rule, do: "update_alert", else: "create_alert"} class="p-6 space-y-5" id="alert-form">
              <div>
                <label class="block text-sm font-medium text-base-content mb-1.5">Name</label>
                <input
                  type="text"
                  name="name"
                  value={if @editing_rule, do: @editing_rule.name, else: ""}
                  placeholder="High Error Rate Alert"
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-base-content mb-1.5">Condition Type</label>
                <select
                  name="condition_type"
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150 cursor-pointer"
                  id="condition-type-select"
                >
                  <option value="threshold" selected={@editing_rule && @editing_rule.condition_type == "threshold"}>
                    Threshold (event count)
                  </option>
                  <option value="new_error" selected={@editing_rule && @editing_rule.condition_type == "new_error"}>
                    New Error (first occurrence)
                  </option>
                  <option value="pattern_match" selected={@editing_rule && @editing_rule.condition_type == "pattern_match"}>
                    Pattern Match (regex)
                  </option>
                </select>
              </div>

              <div id="threshold-config">
                <label class="block text-sm font-medium text-base-content mb-1.5">Threshold Count</label>
                <input
                  type="number"
                  name="threshold_count"
                  value={get_config_value(@editing_rule, "count", "10")}
                  min="1"
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                />
                <p class="mt-1 text-xs text-base-content/50">Number of events to trigger alert</p>
              </div>

              <div>
                <label class="block text-sm font-medium text-base-content mb-1.5">Webhook URL</label>
                <input
                  type="url"
                  name="webhook_url"
                  value={if @editing_rule, do: @editing_rule.webhook_url, else: ""}
                  placeholder="https://hooks.slack.com/services/..."
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150 font-mono text-sm"
                  required
                />
                <p class="mt-1 text-xs text-base-content/50">URL to receive webhook notifications</p>
              </div>

              <div class="flex items-center justify-end gap-3 pt-4 border-t border-base-200">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="px-4 py-2 rounded-lg text-sm font-medium text-base-content hover:bg-base-200 transition-colors duration-150"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 rounded-lg bg-primary text-primary-content text-sm font-medium hover:brightness-110 transition-all duration-150 shadow-sm"
                >
                  {if @editing_rule, do: "Save Changes", else: "Create Alert"}
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp format_condition(rule) do
    case rule.condition_type do
      "threshold" ->
        count = get_in(rule.condition_config, ["count"]) || 10
        "Triggers when #{count}+ events occur"

      "new_error" ->
        "Triggers on first occurrence of an error"

      "pattern_match" ->
        pattern = get_in(rule.condition_config, ["pattern"]) || ""
        "Triggers when message matches: #{pattern}"

      _ ->
        "Unknown condition"
    end
  end

  defp get_config_value(nil, _key, default), do: default
  defp get_config_value(rule, key, default) do
    get_in(rule.condition_config, [key]) || default
  end
end
