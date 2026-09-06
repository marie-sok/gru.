# Contributing to gru.

The repository is currently in a **0.9.x closed-beta stabilization phase**.

## Branch policy

- `verification` — integration baseline.
- `beta/0.9.0` — active closed-beta stabilization branch.
- new feature work should not be merged into `beta/0.9.0` unless it resolves a beta blocker.

## Allowed beta changes

Before the first TestFlight build, prefer only:

- crash fixes;
- auth/session fixes;
- networking/reconnect fixes;
- message consistency fixes;
- media/capture fixes;
- release/signing/configuration fixes;
- accessibility fixes that block core flows.

Large new features should wait for the next development line.

## Pull requests

A beta PR should state:

1. what problem it fixes;
2. which physical-device flow was tested;
3. whether it changes persistence/network protocol behavior;
4. rollback risk;
5. any remaining known limitation.

## Security

Never commit API keys, JWT secrets, signing material, production credentials or private provisioning files.

## Ownership

Primary author and maintainer: **Marie Sok (`@marie-sok`)**.

See [`AUTHORS.md`](./AUTHORS.md).
