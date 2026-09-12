# GRU edge proxy

Production reverse proxy for REST and STOMP/WebSocket traffic.

## Required environment

- `GRU_UPSTREAM_URL=https://gru-jiqi.onrender.com`
- `PORT` is supplied by the hosting platform.

## Render service

- Runtime: Node
- Root directory: `proxy`
- Build command: `npm ci`
- Start command: `npm start`
- Health path: `/health`
- Region: Frankfurt for the current European beta

After deployment, map the GRU API hostname to this service and set the iOS Release values:

- `GRUProductionHTTPBaseURL=https://<proxy-host>`
- `GRUProductionWebSocketURL=wss://<proxy-host>/ws`

The proxy forwards `Authorization` and WebSocket upgrade headers but never logs authorization values, cookies, request bodies, E2EE envelopes, recovery backups, or media metadata. The backend remains the authority for authentication, authorization, rate limiting, E2EE validation, media limits and moderation.

Do not point a TestFlight build at the proxy until `/health`, `/ready`, login, E2EE A↔B and WebSocket reconnect smokes have passed through the proxy.
