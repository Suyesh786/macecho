# MacEcho

MacEcho is a native Android companion application for macOS, designed to bring important phone interactions to a Mac through a secure, lightweight, and reliable foundation.

## Repository structure

- `docs/` — the project's architecture, product, security, protocol, and planning documentation.
- `android/` — the future native Android application.
- `macos/` — the future native macOS menu bar application.
- `backend/` — the future backend relay services.
- `shared/` — shared cross-platform resources, including protocol-related materials.
- `assets/` — branding, icons, screenshots, and other design assets.

## High-level architecture

MacEcho is a modular distributed system comprising an Android application, a macOS application, a backend relay, a shared communication protocol, and first-class documentation and configuration. Device communication is relayed through the backend; the native applications do not communicate directly with each other.

See the [Project Overview](docs/00_PROJECT_OVERVIEW.md) and the complete [documentation](docs/) for the authoritative design.

## Development philosophy

MacEcho is developed architecture-first, with native platform integration, security and privacy by default, modular boundaries, and long-term maintainability. Documentation takes precedence over assumptions.

All implementation follows the documentation in `docs/`. Work proceeds one documented phase at a time; no undocumented behavior or future-phase work is introduced.
