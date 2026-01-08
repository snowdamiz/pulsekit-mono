defmodule PulsekitWeb.Router do
  use PulsekitWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PulsekitWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug PulsekitWeb.Plugs.ApiAuth
  end

  # Browser routes
  scope "/", PulsekitWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/events", EventsLive, :index
    live "/events/:id", EventDetailLive, :show
    live "/projects", ProjectsLive, :index
    live "/projects/new", ProjectsLive, :new
    live "/projects/:id", ProjectDetailLive, :show
    live "/projects/:id/edit", ProjectDetailLive, :edit
    live "/alerts", AlertsLive, :index
    live "/alerts/new", AlertsLive, :new
    live "/alerts/:id/edit", AlertsLive, :edit
    live "/organizations", OrganizationsLive, :index
    live "/organizations/new", OrganizationsLive, :new
    live "/organizations/:id", OrganizationDetailLive, :show
    live "/organizations/:id/edit", OrganizationDetailLive, :edit
    live "/settings", SettingsLive, :index
  end

  # Public API routes (no auth required)
  scope "/api/v1", PulsekitWeb.Api.V1 do
    pipe_through :api

    get "/health", HealthController, :index
  end

  # Authenticated API routes
  scope "/api/v1", PulsekitWeb.Api.V1 do
    pipe_through :api_auth

    post "/events", EventController, :create
    post "/events/batch", EventController, :batch
  end
end
