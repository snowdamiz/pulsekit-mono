// Package pulsekit provides a Go SDK for PulseKit error tracking and event monitoring.
package pulsekit

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"runtime"
	"sync"
	"time"
)

// Level represents the severity level of an event.
type Level string

const (
	LevelDebug   Level = "debug"
	LevelInfo    Level = "info"
	LevelWarning Level = "warning"
	LevelError   Level = "error"
	LevelFatal   Level = "fatal"
)

// Config holds the configuration for the PulseKit client.
type Config struct {
	// Endpoint is the PulseKit server URL
	Endpoint string
	// APIKey is your project API key
	APIKey string
	// Environment is the deployment environment (e.g., "production", "staging")
	Environment string
	// Release is the application version
	Release string
	// BatchSize is the number of events to batch before sending
	BatchSize int
	// FlushInterval is the interval between automatic flushes
	FlushInterval time.Duration
	// Debug enables debug logging
	Debug bool
}

// Event represents an event to be sent to PulseKit.
type Event struct {
	Type        string                 `json:"type"`
	Level       Level                  `json:"level,omitempty"`
	Message     string                 `json:"message,omitempty"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
	Stacktrace  []StackFrame           `json:"stacktrace,omitempty"`
	Tags        map[string]string      `json:"tags,omitempty"`
	Timestamp   string                 `json:"timestamp,omitempty"`
	Fingerprint string                 `json:"fingerprint,omitempty"`
	Environment string                 `json:"environment,omitempty"`
	Release     string                 `json:"release,omitempty"`
}

// StackFrame represents a single frame in a stack trace.
type StackFrame struct {
	File     string `json:"file,omitempty"`
	Line     int    `json:"line,omitempty"`
	Function string `json:"function,omitempty"`
}

// Client is the PulseKit client for sending events.
type Client struct {
	config     Config
	httpClient *http.Client
	queue      []Event
	mu         sync.Mutex
	done       chan struct{}
	wg         sync.WaitGroup
}

var defaultClient *Client

// Init initializes the default PulseKit client.
func Init(config Config) error {
	client, err := NewClient(config)
	if err != nil {
		return err
	}
	defaultClient = client
	return nil
}

// NewClient creates a new PulseKit client.
func NewClient(config Config) (*Client, error) {
	if config.Endpoint == "" {
		return nil, fmt.Errorf("endpoint is required")
	}
	if config.APIKey == "" {
		return nil, fmt.Errorf("api key is required")
	}

	if config.BatchSize <= 0 {
		config.BatchSize = 10
	}
	if config.FlushInterval <= 0 {
		config.FlushInterval = 5 * time.Second
	}
	if config.Environment == "" {
		config.Environment = "production"
	}

	c := &Client{
		config:     config,
		httpClient: &http.Client{Timeout: 10 * time.Second},
		queue:      make([]Event, 0, config.BatchSize),
		done:       make(chan struct{}),
	}

	c.wg.Add(1)
	go c.flushLoop()

	return c, nil
}

// CaptureException captures an error with stack trace.
func CaptureException(err error, opts ...EventOption) {
	if defaultClient == nil {
		return
	}
	defaultClient.CaptureException(err, opts...)
}

// CaptureException captures an error with stack trace.
func (c *Client) CaptureException(err error, opts ...EventOption) {
	if err == nil {
		return
	}

	event := Event{
		Type:       "error",
		Level:      LevelError,
		Message:    err.Error(),
		Stacktrace: captureStackTrace(3),
	}

	for _, opt := range opts {
		opt(&event)
	}

	c.enqueue(event)
}

// Capture sends a custom event.
func Capture(event Event) {
	if defaultClient == nil {
		return
	}
	defaultClient.Capture(event)
}

// Capture sends a custom event.
func (c *Client) Capture(event Event) {
	c.enqueue(event)
}

// CaptureMessage sends a simple message event.
func CaptureMessage(message string, level Level, opts ...EventOption) {
	if defaultClient == nil {
		return
	}
	defaultClient.CaptureMessage(message, level, opts...)
}

// CaptureMessage sends a simple message event.
func (c *Client) CaptureMessage(message string, level Level, opts ...EventOption) {
	event := Event{
		Type:    "message",
		Level:   level,
		Message: message,
	}

	for _, opt := range opts {
		opt(&event)
	}

	c.enqueue(event)
}

// Flush sends all queued events immediately.
func Flush() {
	if defaultClient == nil {
		return
	}
	defaultClient.Flush()
}

// Flush sends all queued events immediately.
func (c *Client) Flush() {
	c.mu.Lock()
	events := c.queue
	c.queue = make([]Event, 0, c.config.BatchSize)
	c.mu.Unlock()

	if len(events) > 0 {
		c.sendEvents(events)
	}
}

// Close flushes remaining events and stops the client.
func Close() {
	if defaultClient == nil {
		return
	}
	defaultClient.Close()
}

// Close flushes remaining events and stops the client.
func (c *Client) Close() {
	close(c.done)
	c.wg.Wait()
	c.Flush()
}

func (c *Client) enqueue(event Event) {
	event.Timestamp = time.Now().UTC().Format(time.RFC3339)
	event.Environment = c.config.Environment
	if c.config.Release != "" {
		event.Release = c.config.Release
	}
	if event.Level == "" {
		event.Level = LevelInfo
	}

	c.mu.Lock()
	c.queue = append(c.queue, event)
	shouldFlush := len(c.queue) >= c.config.BatchSize
	c.mu.Unlock()

	if shouldFlush {
		c.Flush()
	}
}

func (c *Client) flushLoop() {
	defer c.wg.Done()

	ticker := time.NewTicker(c.config.FlushInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			c.Flush()
		case <-c.done:
			return
		}
	}
}

func (c *Client) sendEvents(events []Event) {
	var url string
	var body interface{}

	if len(events) == 1 {
		url = c.config.Endpoint + "/api/v1/events"
		body = events[0]
	} else {
		url = c.config.Endpoint + "/api/v1/events/batch"
		body = map[string]interface{}{"events": events}
	}

	jsonBody, err := json.Marshal(body)
	if err != nil {
		if c.config.Debug {
			fmt.Printf("[PulseKit] Failed to marshal events: %v\n", err)
		}
		return
	}

	req, err := http.NewRequest("POST", url, bytes.NewReader(jsonBody))
	if err != nil {
		if c.config.Debug {
			fmt.Printf("[PulseKit] Failed to create request: %v\n", err)
		}
		return
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-PulseKit-Key", c.config.APIKey)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		if c.config.Debug {
			fmt.Printf("[PulseKit] Failed to send events: %v\n", err)
		}
		return
	}
	defer resp.Body.Close()

	if c.config.Debug {
		fmt.Printf("[PulseKit] Sent %d event(s), status: %d\n", len(events), resp.StatusCode)
	}
}

func captureStackTrace(skip int) []StackFrame {
	var frames []StackFrame
	pcs := make([]uintptr, 50)
	n := runtime.Callers(skip, pcs)
	pcs = pcs[:n]

	callersFrames := runtime.CallersFrames(pcs)
	for {
		frame, more := callersFrames.Next()
		frames = append(frames, StackFrame{
			File:     frame.File,
			Line:     frame.Line,
			Function: frame.Function,
		})
		if !more {
			break
		}
	}

	return frames
}

// EventOption is a function that modifies an event.
type EventOption func(*Event)

// WithTags adds tags to an event.
func WithTags(tags map[string]string) EventOption {
	return func(e *Event) {
		if e.Tags == nil {
			e.Tags = make(map[string]string)
		}
		for k, v := range tags {
			e.Tags[k] = v
		}
	}
}

// WithMetadata adds metadata to an event.
func WithMetadata(metadata map[string]interface{}) EventOption {
	return func(e *Event) {
		if e.Metadata == nil {
			e.Metadata = make(map[string]interface{})
		}
		for k, v := range metadata {
			e.Metadata[k] = v
		}
	}
}

// WithType sets the event type.
func WithType(eventType string) EventOption {
	return func(e *Event) {
		e.Type = eventType
	}
}

// WithLevel sets the event level.
func WithLevel(level Level) EventOption {
	return func(e *Event) {
		e.Level = level
	}
}

// WithFingerprint sets the event fingerprint.
func WithFingerprint(fingerprint string) EventOption {
	return func(e *Event) {
		e.Fingerprint = fingerprint
	}
}

