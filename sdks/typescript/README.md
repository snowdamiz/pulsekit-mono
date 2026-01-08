# @120356aa/pulsekit-sdk

Official PulseKit SDK for TypeScript/JavaScript applications.

## Installation

```bash
npm install @120356aa/pulsekit-sdk
# or
yarn add @120356aa/pulsekit-sdk
# or
pnpm add @120356aa/pulsekit-sdk
```

## Quick Start

```typescript
import { PulseKit } from '@120356aa/pulsekit-sdk';

const pulse = new PulseKit({
  endpoint: 'https://your-pulsekit-instance.com',
  apiKey: 'pk_your_api_key',
  environment: 'production',
  release: '1.0.0',
});

// Automatic error capturing is enabled by default
// Errors will be automatically sent to PulseKit

// Manually capture an error
try {
  throw new Error('Something went wrong');
} catch (error) {
  pulse.captureException(error);
}

// Send a custom event
pulse.capture({
  type: 'payment.success',
  level: 'info',
  message: 'Payment completed successfully',
  metadata: {
    amount: 99.99,
    currency: 'USD',
    orderId: 'order_123',
  },
  tags: {
    customer_id: 'cust_456',
  },
});

// Send a simple message
pulse.captureMessage('User signed up', 'info', {
  tags: { user_id: 'user_789' },
});
```

## Configuration

```typescript
const pulse = new PulseKit({
  // Required
  endpoint: 'https://your-pulsekit-instance.com',
  apiKey: 'pk_your_api_key',
  
  // Optional
  environment: 'production',  // Default: 'production'
  release: '1.0.0',           // Your app version
  debug: false,               // Enable debug logging
  batchSize: 10,              // Events to batch before sending
  flushInterval: 5000,        // Flush interval in ms
  autoCapture: true,          // Auto-capture unhandled errors
});
```

## Using Scopes

Scopes allow you to add context to events:

```typescript
pulse.withScope((scope) => {
  scope.setTag('transaction_id', 'txn_123');
  scope.setExtra('cart_items', ['item1', 'item2']);
  
  scope.captureMessage('Checkout started', 'info');
});
```

## Event Levels

- `debug` - Detailed debugging information
- `info` - General information
- `warning` - Warning conditions
- `error` - Error conditions
- `fatal` - Critical errors

## Browser Support

The SDK works in all modern browsers and Node.js 18+.

## License

MIT

