/**
 * PulseKit SDK for TypeScript/JavaScript
 * Error tracking and event monitoring
 */

export interface PulseKitConfig {
  /** The PulseKit server endpoint URL */
  endpoint: string;
  /** Your project API key */
  apiKey: string;
  /** Environment name (e.g., 'production', 'staging') */
  environment?: string;
  /** Release/version identifier */
  release?: string;
  /** Enable debug logging */
  debug?: boolean;
  /** Maximum events to batch before sending */
  batchSize?: number;
  /** Flush interval in milliseconds */
  flushInterval?: number;
  /** Enable automatic error capturing */
  autoCapture?: boolean;
}

export type EventLevel = 'debug' | 'info' | 'warning' | 'error' | 'fatal';

export interface EventPayload {
  /** Event type identifier (e.g., 'error', 'payment.success') */
  type: string;
  /** Event severity level */
  level?: EventLevel;
  /** Human-readable message */
  message?: string;
  /** Additional structured data */
  metadata?: Record<string, unknown>;
  /** Stack trace information */
  stacktrace?: StackFrame[] | string;
  /** Custom tags for filtering */
  tags?: Record<string, string>;
  /** Event timestamp (defaults to now) */
  timestamp?: string | Date;
  /** Unique fingerprint for grouping similar events */
  fingerprint?: string;
}

export interface StackFrame {
  file?: string;
  line?: number;
  column?: number;
  function?: string;
}

interface QueuedEvent extends EventPayload {
  environment?: string;
  release?: string;
}

/**
 * PulseKit client for sending events and capturing errors
 */
export class PulseKit {
  private config: Required<PulseKitConfig>;
  private queue: QueuedEvent[] = [];
  private flushTimer: ReturnType<typeof setTimeout> | null = null;
  private isInitialized = false;

  constructor(config: PulseKitConfig) {
    this.config = {
      endpoint: config.endpoint.replace(/\/$/, ''),
      apiKey: config.apiKey,
      environment: config.environment || 'production',
      release: config.release || '',
      debug: config.debug || false,
      batchSize: config.batchSize || 10,
      flushInterval: config.flushInterval || 5000,
      autoCapture: config.autoCapture ?? true,
    };

    this.init();
  }

  private init(): void {
    if (this.isInitialized) return;
    this.isInitialized = true;

    if (this.config.autoCapture) {
      this.setupAutomaticCapture();
    }

    this.startFlushTimer();

    // Flush on page unload
    if (typeof window !== 'undefined') {
      window.addEventListener('beforeunload', () => this.flush());
      window.addEventListener('pagehide', () => this.flush());
    }

    // Flush on process exit (Node.js)
    if (typeof process !== 'undefined' && process.on) {
      process.on('beforeExit', () => this.flush());
    }

    this.log('PulseKit initialized');
  }

  private setupAutomaticCapture(): void {
    // Browser error handling
    if (typeof window !== 'undefined') {
      window.addEventListener('error', (event) => {
        this.captureException(event.error || new Error(event.message), {
          metadata: {
            filename: event.filename,
            lineno: event.lineno,
            colno: event.colno,
          },
        });
      });

      window.addEventListener('unhandledrejection', (event) => {
        const error = event.reason instanceof Error 
          ? event.reason 
          : new Error(String(event.reason));
        this.captureException(error, {
          type: 'unhandledrejection',
        });
      });
    }

    // Node.js error handling
    if (typeof process !== 'undefined' && process.on) {
      process.on('uncaughtException', (error) => {
        this.captureException(error, { type: 'uncaughtException' });
        this.flush();
      });

      process.on('unhandledRejection', (reason) => {
        const error = reason instanceof Error 
          ? reason 
          : new Error(String(reason));
        this.captureException(error, { type: 'unhandledRejection' });
      });
    }
  }

  /**
   * Capture an exception/error
   */
  captureException(
    error: Error | unknown,
    options: Partial<EventPayload> = {}
  ): void {
    const err = error instanceof Error ? error : new Error(String(error));
    
    const event: EventPayload = {
      type: options.type || 'error',
      level: options.level || 'error',
      message: err.message,
      stacktrace: this.parseStackTrace(err.stack),
      metadata: {
        name: err.name,
        ...options.metadata,
      },
      tags: options.tags,
      fingerprint: options.fingerprint,
    };

    this.capture(event);
  }

  /**
   * Capture a custom event
   */
  capture(event: EventPayload): void {
    const queuedEvent: QueuedEvent = {
      ...event,
      level: event.level || 'info',
      timestamp: event.timestamp 
        ? (event.timestamp instanceof Date ? event.timestamp.toISOString() : event.timestamp)
        : new Date().toISOString(),
      environment: this.config.environment,
      release: this.config.release || undefined,
    };

    this.queue.push(queuedEvent);
    this.log('Event queued:', queuedEvent.type);

    if (this.queue.length >= this.config.batchSize) {
      this.flush();
    }
  }

  /**
   * Send a simple message event
   */
  captureMessage(
    message: string,
    level: EventLevel = 'info',
    options: Partial<EventPayload> = {}
  ): void {
    this.capture({
      type: options.type || 'message',
      level,
      message,
      metadata: options.metadata,
      tags: options.tags,
    });
  }

  /**
   * Flush all queued events to the server
   */
  async flush(): Promise<void> {
    if (this.queue.length === 0) return;

    const events = [...this.queue];
    this.queue = [];

    try {
      if (events.length === 1) {
        await this.sendEvent(events[0]);
      } else {
        await this.sendBatch(events);
      }
      this.log(`Flushed ${events.length} event(s)`);
    } catch (error) {
      this.log('Failed to flush events:', error);
      // Re-queue events on failure
      this.queue = [...events, ...this.queue];
    }
  }

  private async sendEvent(event: QueuedEvent): Promise<void> {
    const response = await fetch(`${this.config.endpoint}/api/v1/events`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-PulseKit-Key': this.config.apiKey,
      },
      body: JSON.stringify(event),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
  }

  private async sendBatch(events: QueuedEvent[]): Promise<void> {
    const response = await fetch(`${this.config.endpoint}/api/v1/events/batch`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-PulseKit-Key': this.config.apiKey,
      },
      body: JSON.stringify({ events }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
  }

  private startFlushTimer(): void {
    if (this.flushTimer) return;
    
    this.flushTimer = setInterval(() => {
      this.flush();
    }, this.config.flushInterval);
  }

  private parseStackTrace(stack?: string): StackFrame[] | undefined {
    if (!stack) return undefined;

    const frames: StackFrame[] = [];
    const lines = stack.split('\n');

    for (const line of lines) {
      // Chrome/Node.js format: "    at functionName (file:line:column)"
      const chromeMatch = line.match(/^\s*at\s+(?:(.+?)\s+\()?(.+?):(\d+):(\d+)\)?$/);
      if (chromeMatch) {
        frames.push({
          function: chromeMatch[1] || '<anonymous>',
          file: chromeMatch[2],
          line: parseInt(chromeMatch[3], 10),
          column: parseInt(chromeMatch[4], 10),
        });
        continue;
      }

      // Firefox format: "functionName@file:line:column"
      const firefoxMatch = line.match(/^(.+?)@(.+?):(\d+):(\d+)$/);
      if (firefoxMatch) {
        frames.push({
          function: firefoxMatch[1] || '<anonymous>',
          file: firefoxMatch[2],
          line: parseInt(firefoxMatch[3], 10),
          column: parseInt(firefoxMatch[4], 10),
        });
      }
    }

    return frames.length > 0 ? frames : undefined;
  }

  private log(...args: unknown[]): void {
    if (this.config.debug) {
      console.log('[PulseKit]', ...args);
    }
  }

  /**
   * Create a new scope with additional context
   */
  withScope(callback: (scope: Scope) => void): void {
    const scope = new Scope(this);
    callback(scope);
  }

  /**
   * Destroy the client and flush remaining events
   */
  async destroy(): Promise<void> {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
      this.flushTimer = null;
    }
    await this.flush();
    this.isInitialized = false;
  }
}

/**
 * Scope for adding context to events
 */
export class Scope {
  private client: PulseKit;
  private tags: Record<string, string> = {};
  private metadata: Record<string, unknown> = {};

  constructor(client: PulseKit) {
    this.client = client;
  }

  setTag(key: string, value: string): this {
    this.tags[key] = value;
    return this;
  }

  setTags(tags: Record<string, string>): this {
    this.tags = { ...this.tags, ...tags };
    return this;
  }

  setExtra(key: string, value: unknown): this {
    this.metadata[key] = value;
    return this;
  }

  setExtras(extras: Record<string, unknown>): this {
    this.metadata = { ...this.metadata, ...extras };
    return this;
  }

  captureException(error: Error | unknown, options: Partial<EventPayload> = {}): void {
    this.client.captureException(error, {
      ...options,
      tags: { ...this.tags, ...options.tags },
      metadata: { ...this.metadata, ...options.metadata },
    });
  }

  captureMessage(message: string, level: EventLevel = 'info', options: Partial<EventPayload> = {}): void {
    this.client.captureMessage(message, level, {
      ...options,
      tags: { ...this.tags, ...options.tags },
      metadata: { ...this.metadata, ...options.metadata },
    });
  }

  capture(event: EventPayload): void {
    this.client.capture({
      ...event,
      tags: { ...this.tags, ...event.tags },
      metadata: { ...this.metadata, ...event.metadata },
    });
  }
}

// Default export for convenience
export default PulseKit;

