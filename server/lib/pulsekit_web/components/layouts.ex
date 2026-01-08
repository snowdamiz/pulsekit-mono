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
      <aside class="fixed left-0 top-0 h-full w-64 bg-base-100 border-r border-base-300 z-40">
        <div class="flex flex-col h-full">
          <%!-- Logo --%>
          <div class="p-4 border-b border-base-300">
            <a href="/" class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-primary to-accent flex items-center justify-center">
                <.icon name="hero-bolt" class="w-6 h-6 text-primary-content" />
              </div>
              <span class="text-xl font-bold tracking-tight">PulseKit</span>
            </a>
          </div>

          <%!-- Organization Selector --%>
          <%= if length(@organizations) > 0 do %>
            <div class="p-3 border-b border-base-300">
              <div class="dropdown w-full">
                <div tabindex="0" role="button" class="btn btn-ghost btn-sm w-full justify-between gap-2 font-normal">
                  <div class="flex items-center gap-2 truncate">
                    <.icon name="hero-building-office-2" class="w-4 h-4 shrink-0 text-primary" />
                    <span class="truncate">{if @current_organization, do: @current_organization.name, else: "Select Workspace"}</span>
                  </div>
                  <.icon name="hero-chevron-up-down" class="w-4 h-4 shrink-0 opacity-50" />
                </div>
                <ul tabindex="0" class="dropdown-content z-[100] menu p-2 shadow-lg bg-base-100 rounded-box w-full border border-base-300 mt-1">
                  <%= for org <- @organizations do %>
                    <li>
                      <a
                        href={"/?org=#{org.id}"}
                        class={[if(@current_organization && @current_organization.id == org.id, do: "active")]}
                      >
                        <.icon name="hero-building-office-2" class="w-4 h-4" />
                        {org.name}
                      </a>
                    </li>
                  <% end %>
                  <li class="border-t border-base-300 mt-1 pt-1">
                    <a href="/organizations">
                      <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
                      Manage Workspaces
                    </a>
                  </li>
                </ul>
              </div>
            </div>
          <% end %>

          <%!-- Navigation --%>
          <nav class="flex-1 p-4 space-y-1">
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
          <div class="p-4 border-t border-base-300 space-y-2">
            <.nav_link href="/organizations" icon="hero-building-office-2" current_path={@current_path}>
              Workspaces
            </.nav_link>
            <.nav_link href="/settings" icon="hero-cog-6-tooth" current_path={@current_path}>
              Settings
            </.nav_link>
            <div class="pt-2">
              <.theme_toggle />
            </div>
          </div>
        </div>
      </aside>

      <%!-- Main content --%>
      <main class="ml-64 min-h-screen">
        <div class="p-6">
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
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-all duration-200",
        if(@active,
          do: "bg-primary text-primary-content shadow-sm",
          else: "text-base-content/70 hover:bg-base-200 hover:text-base-content"
        )
      ]}
    >
      <.icon name={@icon} class="w-5 h-5" />
      {render_slot(@inner_block)}
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
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
