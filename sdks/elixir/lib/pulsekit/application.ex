defmodule PulseKit.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PulseKit.Client
    ]

    opts = [strategy: :one_for_one, name: PulseKit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
