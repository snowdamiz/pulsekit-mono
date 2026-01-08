defmodule Pulsekit.Accounts do
  @moduledoc """
  The Accounts context - manages user authentication and management.
  """

  require Logger
  import Ecto.Query, warn: false
  alias Pulsekit.Repo
  alias Pulsekit.Accounts.User

  @doc """
  Returns the list of all users.
  """
  def list_users do
    Repo.all(from u in User, order_by: [desc: u.is_master, asc: u.email])
  end

  @doc """
  Gets a single user by ID.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && User.valid_password?(user, password) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        # Prevent timing attacks
        Pbkdf2.no_user_verify()
        {:error, :user_not_found}
    end
  end

  @doc """
  Creates a new user (for invitations).
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(normalize_email(attrs))
    |> Repo.insert()
  end

  @doc """
  Deletes a user. Cannot delete the master user.
  """
  def delete_user(%User{is_master: true}), do: {:error, :cannot_delete_master}

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Changes a user's password.
  """
  def change_user_password(%User{} = user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  @doc """
  Ensures the master user exists based on environment variables.
  Called on application start.
  """
  def ensure_master_user do
    master_email = System.get_env("PULSEKIT_MASTER_EMAIL")
    master_password = System.get_env("PULSEKIT_MASTER_PASSWORD")

    cond do
      is_nil(master_email) or is_nil(master_password) ->
        Logger.warning("Master user not configured: PULSEKIT_MASTER_EMAIL or PULSEKIT_MASTER_PASSWORD not set")
        :ok

      master_email == "" or master_password == "" ->
        Logger.warning("Master user not configured: PULSEKIT_MASTER_EMAIL or PULSEKIT_MASTER_PASSWORD is empty")
        :ok

      true ->
        Logger.info("Ensuring master user exists: #{master_email}")
        create_or_update_master_user(master_email, master_password)
    end
  end

  defp create_or_update_master_user(email, password) do
    email = String.downcase(email)

    result = case Repo.get_by(User, email: email) do
      nil ->
        Logger.info("Creating new master user: #{email}")
        %User{}
        |> User.master_changeset(%{email: email, password: password})
        |> Repo.insert()

      %User{is_master: true} = user ->
        Logger.info("Updating existing master user: #{email}")
        user
        |> User.password_changeset(%{password: password})
        |> Repo.update()

      %User{is_master: false} = user ->
        Logger.info("Promoting user to master: #{email}")
        user
        |> Ecto.Changeset.change(%{is_master: true})
        |> User.password_changeset(%{password: password})
        |> Repo.update()
    end

    case result do
      {:ok, user} ->
        Logger.info("Master user ready: #{user.email}")
        {:ok, user}

      {:error, changeset} ->
        Logger.error("Failed to create/update master user: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp normalize_email(attrs) do
    case attrs do
      %{email: email} when is_binary(email) ->
        Map.put(attrs, :email, String.downcase(email))

      %{"email" => email} when is_binary(email) ->
        Map.put(attrs, "email", String.downcase(email))

      _ ->
        attrs
    end
  end
end
