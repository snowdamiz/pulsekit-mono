defmodule Pulsekit.Repo do
  use Ecto.Repo,
    otp_app: :pulsekit,
    adapter: Ecto.Adapters.SQLite3
end
