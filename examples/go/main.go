// PulseKit Go SDK Test
//
// Before running this test:
// 1. Make sure PulseKit is running at http://localhost:4000
// 2. Create a project in PulseKit: http://localhost:4000/projects/new
// 3. Get an API key from the project detail page
// 4. Set the PULSEKIT_API_KEY environment variable or update the key below
//
// Run: go run main.go

package main

import (
	"fmt"
	"os"
	"time"

	pulsekit "github.com/pulsekit/go"
)

func main() {
	apiKey := os.Getenv("PULSEKIT_API_KEY")
	if apiKey == "" {
		apiKey = "pk_YOUR_API_KEY_HERE"
	}

	fmt.Println("🧪 PulseKit Go SDK Test\n")
	fmt.Println("Endpoint: http://localhost:4000")
	fmt.Printf("API Key: %s...\n", apiKey[:min(10, len(apiKey))])
	fmt.Println("")

	// Initialize PulseKit
	pulsekit.Init(pulsekit.Config{
		Endpoint:    "http://localhost:4000",
		APIKey:      apiKey,
		Environment: "development",
		Release:     "1.0.0",
		Debug:       true,
	})
	defer pulsekit.Close()

	// Test 1: Send a custom info event
	fmt.Println("📤 Test 1: Sending custom info event...")
	pulsekit.Capture(pulsekit.Event{
		Type:    "test.info",
		Level:   pulsekit.LevelInfo,
		Message: "This is a test info event from Go SDK",
		Metadata: map[string]interface{}{
			"test_id":   1,
			"sdk":       "go",
			"timestamp": time.Now().Format(time.RFC3339),
		},
		Tags: map[string]string{
			"source":   "test-script",
			"language": "go",
		},
	})
	fmt.Println("✅ Info event sent\n")

	// Test 2: Capture an exception
	fmt.Println("📤 Test 2: Capturing exception...")
	err := fmt.Errorf("test error from Go SDK")
	pulsekit.CaptureException(err)
	fmt.Println("✅ Exception captured\n")

	// Test 3: Send a custom business event
	fmt.Println("📤 Test 3: Sending business event...")
	pulsekit.Capture(pulsekit.Event{
		Type:    "payment.success",
		Level:   pulsekit.LevelInfo,
		Message: "Payment processed successfully",
		Metadata: map[string]interface{}{
			"amount":         99.99,
			"currency":       "USD",
			"order_id":       "ORD-12345",
			"customer_email": "test@example.com",
		},
		Tags: map[string]string{
			"payment_method": "credit_card",
			"country":        "US",
		},
	})
	fmt.Println("✅ Business event sent\n")

	// Test 4: Send warning event
	fmt.Println("📤 Test 4: Sending warning event...")
	pulsekit.Capture(pulsekit.Event{
		Type:    "rate_limit.warning",
		Level:   pulsekit.LevelWarning,
		Message: "API rate limit approaching threshold",
		Metadata: map[string]interface{}{
			"current_rate": 950,
			"limit":        1000,
			"reset_time":   "60s",
		},
	})
	fmt.Println("✅ Warning event sent\n")

	// Flush remaining events
	fmt.Println("📤 Flushing remaining events...")
	pulsekit.Flush()
	fmt.Println("✅ All events flushed\n")

	fmt.Println("✨ All tests completed!")
	fmt.Println("Check the PulseKit dashboard at http://localhost:4000 to see your events.")
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

