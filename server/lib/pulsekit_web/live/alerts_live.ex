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
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">Alerts</h1>
            <p class="text-base-content/60 mt-1">Configure webhook alerts for your events</p>
          </div>

          <div class="flex items-center gap-4">
            <%= if length(@projects) > 0 do %>
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-outline gap-2">
                  <.icon name="hero-folder" class="w-4 h-4" />
                  {if @selected_project, do: @selected_project.name, else: "Select Project"}
                  <.icon name="hero-chevron-down" class="w-4 h-4" />
                </div>
                <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-box w-52 border border-base-300">
                  <%= for project <- @projects do %>
                    <li>
                      <button
                        phx-click="select_project"
                        phx-value-id={project.id}
                        class={[if(@selected_project && @selected_project.id == project.id, do: "active")]}
                      >
                        {project.name}
                      </button>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>

            <%= if @selected_project do %>
              <a href="/alerts/new" class="btn btn-primary">
                <.icon name="hero-plus" class="w-4 h-4" />
                New Alert
              </a>
            <% end %>
          </div>
        </div>

        <%= if @selected_project do %>
          <%!-- Alert Rules --%>
          <%= if length(@alert_rules) == 0 do %>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body items-center text-center py-16">
                <.icon name="hero-bell-slash" class="w-16 h-16 text-base-content/30" />
                <h2 class="card-title mt-4">No alert rules yet</h2>
                <p class="text-base-content/60 max-w-md">
                  Create alert rules to get notified via webhooks when specific events occur.
                </p>
                <div class="card-actions mt-4">
                  <a href="/alerts/new" class="btn btn-primary">
                    <.icon name="hero-plus" class="w-4 h-4" />
                    Create Alert Rule
                  </a>
                </div>
              </div>
            </div>
          <% else %>
            <div class="space-y-4">
              <%= for rule <- @alert_rules do %>
                <div class="card bg-base-100 border border-base-300">
                  <div class="card-body">
                    <div class="flex items-start justify-between">
                      <div class="flex items-center gap-4">
                        <div class={[
                          "w-3 h-3 rounded-full",
                          if(rule.enabled, do: "bg-success", else: "bg-base-300")
                        ]} />
                        <div>
                          <h3 class="font-bold">{rule.name}</h3>
                          <p class="text-sm text-base-content/60 mt-1">
                            {format_condition(rule)}
                          </p>
                        </div>
                      </div>

                      <div class="flex items-center gap-2">
                        <button
                          phx-click="toggle_alert"
                          phx-value-id={rule.id}
                          class="btn btn-ghost btn-sm"
                        >
                          <%= if rule.enabled do %>
                            <.icon name="hero-pause" class="w-4 h-4" />
                          <% else %>
                            <.icon name="hero-play" class="w-4 h-4" />
                          <% end %>
                        </button>
                        <a href={"/alerts/#{rule.id}/edit"} class="btn btn-ghost btn-sm">
                          <.icon name="hero-pencil" class="w-4 h-4" />
                        </a>
                        <button
                          phx-click="delete_alert"
                          phx-value-id={rule.id}
                          data-confirm="Are you sure you want to delete this alert rule?"
                          class="btn btn-ghost btn-sm text-error"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" />
                        </button>
                      </div>
                    </div>

                    <div class="mt-4 pt-4 border-t border-base-300">
                      <div class="flex items-center gap-2 text-sm text-base-content/60">
                        <.icon name="hero-link" class="w-4 h-4" />
                        <span class="truncate">{rule.webhook_url}</span>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body items-center text-center py-16">
              <.icon name="hero-folder-plus" class="w-16 h-16 text-base-content/30" />
              <h2 class="card-title mt-4">No projects yet</h2>
              <p class="text-base-content/60">Create a project first to configure alerts.</p>
              <div class="card-actions mt-4">
                <a href="/projects/new" class="btn btn-primary">Create Project</a>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Alert Modal --%>
      <%= if @show_modal do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-lg">
            <button phx-click="close_modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>

            <h3 class="font-bold text-lg mb-4">
              {if @editing_rule, do: "Edit Alert Rule", else: "Create Alert Rule"}
            </h3>

            <form phx-submit={if @editing_rule, do: "update_alert", else: "create_alert"} class="space-y-4" id="alert-form">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Name</span>
                </label>
                <input
                  type="text"
                  name="name"
                  value={if @editing_rule, do: @editing_rule.name, else: ""}
                  placeholder="High Error Rate Alert"
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Condition Type</span>
                </label>
                <select name="condition_type" class="select select-bordered w-full" id="condition-type-select">
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

              <%!-- Threshold Config --%>
              <div class="form-control" id="threshold-config">
                <label class="label">
                  <span class="label-text">Threshold Count</span>
                </label>
                <input
                  type="number"
                  name="threshold_count"
                  value={get_config_value(@editing_rule, "count", "10")}
                  min="1"
                  class="input input-bordered w-full"
                />
                <label class="label">
                  <span class="label-text-alt">Number of events to trigger alert</span>
                </label>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Webhook URL</span>
                </label>
                <input
                  type="url"
                  name="webhook_url"
                  value={if @editing_rule, do: @editing_rule.webhook_url, else: ""}
                  placeholder="https://hooks.slack.com/services/..."
                  class="input input-bordered w-full"
                  required
                />
                <label class="label">
                  <span class="label-text-alt">URL to receive webhook notifications</span>
                </label>
              </div>

              <div class="modal-action">
                <button type="button" phx-click="close_modal" class="btn btn-ghost">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary">
                  {if @editing_rule, do: "Save Changes", else: "Create Alert"}
                </button>
              </div>
            </form>
          </div>
          <div class="modal-backdrop bg-base-300/50" phx-click="close_modal"></div>
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
