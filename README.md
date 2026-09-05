# gru.

**An independent iOS messenger built around privacy, presence and a calmer kind of communication.**

`gru.` is my attempt to rethink what a messenger can feel like when it is not designed by committee and not optimized to become another noisy social feed.

I am building it as a focused iOS-first product: fast, tactile, visually distinctive and intentionally personal.

## Why I am building it

Most messengers have converged on the same interface, the same interaction patterns and the same growth mechanics. I want `gru.` to move in a different direction:

- communication first, content feed second;
- a strong visual identity instead of a clone of an existing messenger;
- expressive media that still feels lightweight;
- presence that is useful without becoming invasive;
- a product that can feel private, premium and human at the same time.

## Product direction

The current product work includes:

- native iOS client in SwiftUI;
- authenticated one-to-one chats;
- realtime messaging over STOMP/WebSocket;
- online presence and typing state;
- unread counters and message delivery/read state;
- replies, reactions and message deletion;
- photo, audio and short video-note interactions;
- a custom visual language, including the GRU envelope and signature media UI;
- a Spring Boot backend with MongoDB and Redis.

## Design principles

**Distinct, not derivative.**  
The goal is not to reproduce Telegram, WhatsApp or iMessage with different colors.

**Private by default.**  
The interface should make direct communication feel direct again.

**Small details matter.**  
Motion, sound, recording states, message actions and empty states are part of the product, not decoration added at the end.

**iOS first.**  
I would rather make one platform feel coherent than rush into every platform with a generic experience.

## Status

`gru.` is in active development. The public repository currently serves as the project page while the product itself is being iterated privately.

The near-term focus is reliability, media flows, account/session handling, push notifications and TestFlight readiness.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the current product direction.

## About the project

`gru.` is an independent project by **Marie Sok**.

There is no large product team behind it. I design the product, make the calls, build the system and iterate on it directly. AI is part of my development workflow as a tool for engineering, review and iteration — not a substitute for product ownership.

That is also the point of the project: a small product can still have a strong point of view.
