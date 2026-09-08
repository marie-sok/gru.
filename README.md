# gru.

**iOS-first realtime messenger with a custom visual language, expressive media and a Spring Boot backend.**

`gru.` is an independent product project focused on one question: what does a messenger look and feel like when the product has a strong point of view instead of copying an existing chat app?

This public repository is the **project showcase and roadmap**. The application itself is being iterated separately.

## Product scope

The current product work covers:

- native iOS client in SwiftUI;
- authenticated one-to-one messaging;
- realtime delivery over STOMP/WebSocket;
- online presence and typing state;
- unread counters and delivery/read state;
- replies, reactions and message deletion;
- photo, audio and short video-note interactions;
- custom chat themes and animated visual backgrounds;
- signature GRU interaction details, including the envelope send control and custom media UI;
- Spring Boot backend with MongoDB and Redis.

## Product thinking

### Distinct, not derivative
The goal is not to rebuild Telegram, WhatsApp or iMessage with another color palette. Navigation, media interactions, themes and micro-interactions are treated as part of the product identity.

### Realtime without visual noise
Presence, typing, delivery state and media are useful only when they support the conversation. The interface is intentionally built around direct communication rather than a content feed.

### Design is part of engineering
Theme systems, recording states, empty states and animation are not late decoration. They influence component boundaries, state handling and the way the application is structured.

## Technical shape

```text
iOS / SwiftUI
      |
      | REST + STOMP/WebSocket
      v
Spring Boot backend
      |---- authentication / chats / messages
      |---- realtime events / presence
      |---- media flows
      v
MongoDB + Redis
```

## Selected interface direction

GRU uses a dark, neon-led visual system with multiple character-driven themes. The visual exploration includes worlds such as **Black Moon Cat**, **Blood Dragon**, **Ultraviolet Unicorn**, **Cyber Midnight**, **Forest Witch** and others.

The design system is intentionally recognizable at a glance: custom envelope interactions, cat-ear media circles, animated theme elements and high-contrast chat surfaces.

## Current focus

- reliability of account/session flows;
- media capture and upload behavior;
- realtime reconnection and delivery correctness;
- push-notification readiness;
- polish for TestFlight-style distribution.

See [ROADMAP.md](ROADMAP.md) for the working product direction.

## What this project demonstrates

`gru.` is my end-to-end product case: product decisions, mobile UI, interaction design, realtime networking, backend integration and iterative debugging all live in the same problem space.

---

**Independent project by Marie Sok.**