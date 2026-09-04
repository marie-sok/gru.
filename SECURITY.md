# Security Policy

## Supported line

Security fixes for the current beta are developed on `beta/0.9.0` and carried forward to later `0.9.x` builds.

## Reporting a vulnerability

Please do **not** publish credentials, tokens, private user data or reproducible security details in a public issue.

For a security-sensitive report:

1. contact the repository owner, **Marie Sok (`@marie-sok`)**, privately; or
2. use GitHub's private security reporting / Security Advisories feature when available for this repository.

Include the affected component, impact, reproduction steps and the smallest safe proof of concept you can provide.

## Secrets

The repository must never contain production API keys, JWT secrets, database credentials, signing certificates, provisioning profiles or private `.env` files.

Production secrets are supplied through deployment configuration and environment variables.
