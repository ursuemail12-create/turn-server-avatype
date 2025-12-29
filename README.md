# Avatype STUN/TURN Server

A production-ready STUN/TURN server for WebRTC applications, designed for deployment on Fly.io.

## Quick Start

### Deploy to Fly.io

```bash
# Make deploy script executable
chmod +x deploy.sh

# Deploy (will prompt for Fly.io login if needed)
./deploy.sh
```

### Local Development

```bash
# Start with Docker Compose
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TURN_AUTH_SECRET` | (generated) | Shared secret for TURN authentication |
| `TURN_REALM` | `turn.avatype.com` | TURN server realm |
| `TURN_MIN_PORT` | `49152` | Minimum UDP relay port |
| `TURN_MAX_PORT` | `49252` | Maximum UDP relay port |

### Setting Secrets on Fly.io

```bash
# Set a custom auth secret
fly secrets set TURN_AUTH_SECRET="your-secret-here" -a avatype-turn

# View current secrets
fly secrets list -a avatype-turn
```

## WebRTC Client Configuration

### Using Time-Limited Credentials (Recommended)

Generate credentials on your backend server:

```javascript
const crypto = require('crypto');

function generateTurnCredentials(secret, ttl = 86400) {
  const timestamp = Math.floor(Date.now() / 1000) + ttl;
  const username = timestamp.toString();
  const hmac = crypto.createHmac('sha1', secret);
  hmac.update(username);
  const password = hmac.digest('base64');
  
  return { username, password };
}

// Usage
const { username, password } = generateTurnCredentials('your-turn-auth-secret');
```

### RTCPeerConnection Configuration

```javascript
const iceServers = [
  {
    urls: 'stun:avatype-turn.fly.dev:3478'
  },
  {
    urls: 'turn:avatype-turn.fly.dev:3478',
    username: username,  // Generated timestamp
    credential: password  // Generated HMAC
  },
  {
    urls: 'turns:avatype-turn.fly.dev:5349',
    username: username,
    credential: password
  }
];

const pc = new RTCPeerConnection({ iceServers });
```

## Testing

### Test STUN Server

```bash
# Using stun-client (npm install -g stun)
stun avatype-turn.fly.dev:3478

# Using curl (basic connectivity)
nc -vzu avatype-turn.fly.dev 3478
```

### Test TURN Server

Use [Trickle ICE](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/) to test your TURN server.

## Monitoring

```bash
# View logs
fly logs -a avatype-turn

# Check status
fly status -a avatype-turn

# SSH into container
fly ssh console -a avatype-turn
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 3478 | UDP/TCP | STUN/TURN |
| 5349 | TCP | TURNS (TLS) |
| 49152-49252 | UDP | Media relay |

## Troubleshooting

### Connection Issues

1. Ensure IPv4 is allocated: `fly ips list -a avatype-turn`
2. Check logs for errors: `fly logs -a avatype-turn`
3. Verify the secret matches between server and client

### Performance

For higher capacity, scale the VM:

```bash
fly scale vm shared-cpu-2x -a avatype-turn
fly scale memory 2048 -a avatype-turn
```

## License

MIT
