# Metadata authorization boundary

E2EE protects message content, not routing metadata. GRU therefore treats metadata authorization as a separate server-side security boundary.

## STOMP

`CONNECT` authenticates the JWT. `SUBSCRIBE` is independently authorized:

- `/topic/presence` — authenticated users only (beta-known privacy limitation: global presence scope);
- `/topic/chat/{chatId}` — chat participants only;
- `/topic/chat/{chatId}/typing` — chat participants only;
- all other `/topic/**` destinations — denied by default.

A valid JWT is not sufficient to subscribe to another chat.

## Media

`GET /media/{fileName}` requires:

1. authenticated principal;
2. a message owning that media path;
3. an existing owning chat;
4. principal membership in that chat.

Unauthorized and unknown media return the same 404 response and blob storage is not touched before authorization succeeds.

## REST

Message and chat service methods must continue to derive sender identity from the authenticated principal and verify participant/sender/receiver ownership for the requested resource. E2EE ciphertext must never be treated as authorization by itself.
