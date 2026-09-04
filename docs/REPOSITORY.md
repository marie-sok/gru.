# Repository Guide

This document describes what belongs in the active **gru. 0.9.x** repository line.

## Active product code

### Native iOS client

`swiftui/GRU/`

The active TestFlight target is the SwiftUI application under `swiftui/GRU/gru.` with the Xcode project `swiftui/GRU/gru..xcodeproj`.

### Backend

`src/` + `pom.xml`

The backend is a Spring Boot / Java 21 service using MongoDB, JWT authentication and WebSocket/STOMP realtime transport.

### Release documentation

- `README.md` — project overview;
- `BETA_0.9.0.md` — beta freeze and acceptance criteria;
- `AUTHORS.md` — authorship;
- `SECURITY.md` — vulnerability reporting;
- `docs/ARCHITECTURE.md` — architecture notes.

## What is intentionally excluded

The beta branch does not keep generated build/cache output, local machine configuration, exported source-to-HTML dumps, runtime logs or obsolete Flutter platform scaffolding.

Those artifacts remain recoverable from Git history when they existed in earlier commits; they are not part of the current product tree.

## Repository rules

1. Product work for the current beta lands on `beta/0.9.0` until the beta is promoted.
2. No production secret is committed.
3. Generated files and local tooling output remain ignored.
4. Native iOS tests involving camera/microphone/video notes are validated on a physical iPhone.
5. A P0 blocker keeps the TestFlight PR in draft state.
6. Large feature work is deferred during beta freeze unless it fixes a blocker.

## Ownership

Project creator and primary maintainer: **Marie Sok (`@marie-sok`)**.
