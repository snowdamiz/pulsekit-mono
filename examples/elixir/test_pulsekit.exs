# PulseKit Elixir SDK Test
#
# Before running this test:
# 1. Make sure PulseKit is running at http://localhost:4000
# 2. Create a project in PulseKit: http://localhost:4000/projects/new
# 3. Get an API key from the project detail page
# 4. Set the PULSEKIT_API_KEY environment variable or update the key below
#
# Run: mix deps.get && mix run test_pulsekit.exs

# Configure PulseKit
api_key = System.get_env("PULSEKIT_API_KEY") || "pk_YOUR_API_KEY_HERE"

Application.put_env(:pulsekit, :endpoint, "http://localhost:4000")
Application.put_env(:pulsekit, :api_key, api_key)
Application.put_env(:pulsekit, :environment, "development")

# Start PulseKit
{:ok, _} = Application.ensure_all_started(:pulsekit)

IO.puts("🧪 PulseKit Elixir SDK Test\n")
IO.puts("Endpoint: http://localhost:4000")
IO.puts("API Key: #{String.slice(api_key, 0, 10)}...")
IO.puts("")

# Test 1: Send a custom info event
IO.puts("📤 Test 1: Sending custom info event...")
PulseKit.capture(%{
  type: "test.info",
  level: :info,
  message: "This is a test info event from Elixir SDK",
  metadata: %{
    test_id: 1,
    sdk: "elixir",
    timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
  },
  tags: %{
    source: "test-script",
    language: "elixir"
  }
})
IO.puts("✅ Info event sent\n")

# Test 2: Capture an exception
IO.puts("📤 Test 2: Capturing exception...")
try do
  raise "Test error from Elixir SDK"
rescue
  e ->
    PulseKit.capture_exception(e, __STACKTRACE__)
    IO.puts("✅ Exception captured\n")
end

# Test 3: Send a custom business event
IO.puts("📤 Test 3: Sending business event...")
PulseKit.capture(%{
  type: "payment.success",
  level: :info,
  message: "Payment processed successfully",
  metadata: %{
    amount: 99.99,
    currency: "USD",
    order_id: "ORD-12345",
    customer_email: "test@example.com"
  },
  tags: %{
    payment_method: "credit_card",
    country: "US"
  }
})
IO.puts("✅ Business event sent\n")

# Test 4: Send warning event
IO.puts("📤 Test 4: Sending warning event...")
PulseKit.capture(%{
  type: "rate_limit.warning",
  level: :warning,
  message: "API rate limit approaching threshold",
  metadata: %{
    current_rate: 950,
    limit: 1000,
    reset_time: "60s"
  }
})
IO.puts("✅ Warning event sent\n")

# Flush remaining events
IO.puts("📤 Flushing remaining events...")
PulseKit.flush()
# Give it a moment to send
:timer.sleep(1000)
IO.puts("✅ All events flushed\n")

IO.puts("✨ All tests completed!")
IO.puts("Check the PulseKit dashboard at http://localhost:4000 to see your events.")
