defmodule PulseKit do
  @moduledoc """
  PulseKit SDK for Elixir - Error tracking and event monitoring.

  ## Configuration

  Add to your `config/config.exs`:

      config :pulsekit,
        endpoint: "https://your-pulsekit-instance.com",
        api_key: "pk_your_api_key",
        environment: "production",
        release: "1.0.0"

  ## Usage

      # Capture an exception
      try do
        raise "Something went wrong"
      rescue
        e -> PulseKit.capture_exception(e, __STACKTRACE__)
      end

      # Send a custom event
      PulseKit.capture(%{
        type: "payment.success",
        level: :info,
        message: "Payment completed",
        metadata: %{amount: 99.99, currency: "USD"},
        tags: %{customer_id: "cust_123"}
      })

      # Send a simple message
      PulseKit.capture_message("User signed up", :info, tags: %{user_id: "user_789"})
  """

  alias PulseKit.Client

  @type level :: :debug | :info | :warning | :error | :fatal

  @type event :: %{
          required(:type) => String.t(),
          optional(:level) => level(),
          optional(:message) => String.t(),
          optional(:metadata) => map(),
          optional(:stacktrace) => list() | String.t(),
          optional(:tags) => map(),
          optional(:timestamp) => DateTime.t() | String.t(),
          optional(:fingerprint) => String.t()
        }

  @doc """
  Capture an exception with its stacktrace.

  ## Examples

      try do
        raise "Something went wrong"
      rescue
        e -> PulseKit.capture_exception(e, __STACKTRACE__)
      end

      # With additional options
      PulseKit.capture_exception(error, stacktrace,
        tags: %{user_id: "123"},
        metadata: %{request_id: "abc"}
      )
  """
  @spec capture_exception(Exception.t(), list(), keyword()) :: :ok | {:error, term()}
  def capture_exception(exception, stacktrace, opts \\ []) do
    event = %{
      type: Keyword.get(opts, :type, "error"),
      level: Keyword.get(opts, :level, :error),
      message: Exception.message(exception),
      metadata: Map.merge(
        %{exception_type: exception.__struct__ |> to_string()},
        Keyword.get(opts, :metadata, %{})
      ),
      stacktrace: format_stacktrace(stacktrace),
      tags: Keyword.get(opts, :tags, %{}),
      fingerprint: Keyword.get(opts, :fingerprint)
    }

    capture(event)
  end

  @doc """
  Capture a custom event.

  ## Examples

      PulseKit.capture(%{
        type: "payment.success",
        level: :info,
        message: "Payment completed",
        metadata: %{amount: 99.99},
        tags: %{customer_id: "cust_123"}
      })
  """
  @spec capture(event()) :: :ok | {:error, term()}
  def capture(event) when is_map(event) do
    Client.send_event(event)
  end

  @doc """
  Capture a simple message.

  ## Examples

      PulseKit.capture_message("User signed up", :info)
      PulseKit.capture_message("Warning!", :warning, tags: %{user_id: "123"})
  """
  @spec capture_message(String.t(), level(), keyword()) :: :ok | {:error, term()}
  def capture_message(message, level \\ :info, opts \\ []) do
    event = %{
      type: Keyword.get(opts, :type, "message"),
      level: level,
      message: message,
      metadata: Keyword.get(opts, :metadata, %{}),
      tags: Keyword.get(opts, :tags, %{})
    }

    capture(event)
  end

  @doc """
  Flush all queued events to the server.
  """
  @spec flush() :: :ok
  def flush do
    Client.flush()
  end

  defp format_stacktrace(stacktrace) when is_list(stacktrace) do
    Enum.map(stacktrace, fn
      {module, function, arity, location} when is_integer(arity) ->
        %{
          module: inspect(module),
          function: "#{function}/#{arity}",
          file: Keyword.get(location, :file) |> to_string(),
          line: Keyword.get(location, :line)
        }

      {module, function, args, location} when is_list(args) ->
        %{
          module: inspect(module),
          function: "#{function}/#{length(args)}",
          file: Keyword.get(location, :file) |> to_string(),
          line: Keyword.get(location, :line)
        }

      other ->
        %{raw: inspect(other)}
    end)
  end

  defp format_stacktrace(stacktrace), do: stacktrace
end
