defmodule PulsekitWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PulsekitWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :page_title, :string, default: nil
  attr :current_path, :string, default: "/"
  attr :current_organization, :map, default: nil
  attr :organizations, :list, default: []

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <%!-- Sidebar --%>
      <aside class="fixed left-0 top-0 h-full w-64 bg-base-100 border-r border-base-300 z-40 flex flex-col">
        <%!-- Logo --%>
        <div class="p-5 border-b border-base-200">
          <a href="/" class="flex items-center gap-3 group">
            <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-primary to-primary/80 flex items-center justify-center shadow-sm group-hover:shadow-md transition-shadow duration-150">
              <.icon name="hero-bolt-solid" class="w-5 h-5 text-primary-content" />
            </div>
            <div>
              <span class="text-lg font-bold tracking-tight text-base-content">PulseKit</span>
              <span class="block text-[10px] uppercase tracking-widest text-base-content/40 font-medium -mt-0.5">Observability</span>
            </div>
          </a>
        </div>

        <%!-- Organization Selector --%>
        <%= if length(@organizations) > 0 do %>
          <div class="px-3 py-3 border-b border-base-200">
            <div class="dropdown w-full">
              <div
                tabindex="0"
                role="button"
                class="flex items-center gap-2 w-full px-3 py-2 rounded-lg text-sm bg-base-200/50 hover:bg-base-200 border border-transparent hover:border-base-300 transition-all duration-150 cursor-pointer"
              >
                <div class="w-7 h-7 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                  <.icon name="hero-building-office-2" class="w-4 h-4 text-primary" />
                </div>
                <div class="flex-1 min-w-0 text-left">
                  <span class="block truncate font-medium text-base-content">
                    {if @current_organization, do: @current_organization.name, else: "Select Workspace"}
                  </span>
                </div>
                <.icon name="hero-chevron-up-down" class="w-4 h-4 flex-shrink-0 text-base-content/40" />
              </div>
              <ul tabindex="0" class="dropdown-content z-[100] mt-2 p-1.5 w-full bg-base-100 rounded-lg border border-base-300 shadow-lg">
                <%= for org <- @organizations do %>
                  <li>
                    <a
                      href={"/?org=#{org.id}"}
                      class={[
                        "flex items-center gap-2.5 px-3 py-2 rounded-md text-sm transition-colors duration-100",
                        if(@current_organization && @current_organization.id == org.id,
                          do: "bg-primary/10 text-primary font-medium",
                          else: "text-base-content hover:bg-base-200"
                        )
                      ]}
                    >
                      <.icon name="hero-building-office-2" class="w-4 h-4" />
                      <span class="truncate">{org.name}</span>
                      <.icon :if={@current_organization && @current_organization.id == org.id} name="hero-check" class="w-4 h-4 ml-auto" />
                    </a>
                  </li>
                <% end %>
                <li class="border-t border-base-200 mt-1.5 pt-1.5">
                  <a
                    href="/organizations"
                    class="flex items-center gap-2.5 px-3 py-2 rounded-md text-sm text-base-content/70 hover:text-base-content hover:bg-base-200 transition-colors duration-100"
                  >
                    <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
                    <span>Manage Workspaces</span>
                  </a>
                </li>
              </ul>
            </div>
          </div>
        <% end %>

        <%!-- Navigation --%>
        <nav class="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
          <p class="px-3 mb-2 text-[10px] font-semibold uppercase tracking-wider text-base-content/40">Main</p>
          <.nav_link href="/" icon="hero-chart-bar" current_path={@current_path}>
            Dashboard
          </.nav_link>
          <.nav_link href="/events" icon="hero-exclamation-triangle" current_path={@current_path}>
            Events
          </.nav_link>
          <.nav_link href="/projects" icon="hero-folder" current_path={@current_path}>
            Projects
          </.nav_link>
          <.nav_link href="/alerts" icon="hero-bell" current_path={@current_path}>
            Alerts
          </.nav_link>
        </nav>

        <%!-- Bottom section --%>
        <div class="px-3 py-4 border-t border-base-200 space-y-1">
          <p class="px-3 mb-2 text-[10px] font-semibold uppercase tracking-wider text-base-content/40">Settings</p>
          <.nav_link href="/organizations" icon="hero-building-office-2" current_path={@current_path}>
            Workspaces
          </.nav_link>
          <.nav_link href="/settings" icon="hero-cog-6-tooth" current_path={@current_path}>
            Settings
          </.nav_link>
          <div class="pt-3 px-1">
            <.theme_toggle />
          </div>
        </div>
      </aside>

      <%!-- Main content --%>
      <main class="ml-64 min-h-screen">
        <div class="p-8 max-w-7xl mx-auto">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :current_path, :string, default: ""
  slot :inner_block, required: true

  defp nav_link(assigns) do
    active = assigns.current_path == assigns.href or
             (assigns.href != "/" and String.starts_with?(assigns.current_path, assigns.href))

    assigns = assign(assigns, :active, active)

    ~H"""
    <a
      href={@href}
      class={[
        "group relative flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all duration-150",
        if(@active,
          do: "bg-primary text-primary-content shadow-sm",
          else: "text-base-content/70 hover:bg-base-200 hover:text-base-content"
        )
      ]}
    >
      <span class={[
        "absolute left-0 top-1/2 -translate-y-1/2 w-1 h-5 rounded-r-full transition-all duration-150",
        if(@active, do: "bg-primary-content/30", else: "bg-transparent group-hover:bg-primary/30")
      ]} />
      <.icon name={@icon} class={["w-5 h-5 transition-colors duration-150", if(@active, do: "", else: "text-base-content/50 group-hover:text-base-content/70")]} />
      <span>{render_slot(@inner_block)}</span>
    </a>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex items-center p-1 rounded-lg bg-base-200 border border-base-300">
      <%!-- Sliding indicator --%>
      <div class={[
        "absolute h-7 w-1/3 rounded-md bg-base-100 shadow-sm border border-base-300 transition-all duration-200 ease-out",
        "left-1 [[data-theme=light]_&]:left-[calc(33.33%+2px)] [[data-theme=dark]_&]:left-[calc(66.66%+3px)]"
      ]} />

      <button
        class="relative z-10 flex items-center justify-center w-1/3 h-7 rounded-md cursor-pointer transition-colors duration-150"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 text-base-content/60 hover:text-base-content transition-colors" />
      </button>

      <button
        class="relative z-10 flex items-center justify-center w-1/3 h-7 rounded-md cursor-pointer transition-colors duration-150"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 text-base-content/60 hover:text-primary transition-colors" />
      </button>

      <button
        class="relative z-10 flex items-center justify-center w-1/3 h-7 rounded-md cursor-pointer transition-colors duration-150"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 text-base-content/60 hover:text-base-content transition-colors" />
      </button>
    </div>
    """
  end
end
