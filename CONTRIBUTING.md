# Contributing to MacEcho

## Documentation-first development

The documentation in `docs/` is the single source of truth. Read the relevant documentation before beginning work and implement its requirements exactly.

Never assume undocumented behavior. If a requirement is ambiguous, incomplete, or conflicts with another document, stop and request clarification before proceeding.

## One Phase Rule

Implement one phase at a time, following `docs/11_IMPLEMENTATION_PLAN.MD`. Do not begin a later phase until the current phase is complete and verified. Never implement future-phase features, even partially or for convenience.

## Branch strategy

`main` is the protected integration branch. Create focused feature branches for a single documented phase or a clearly bounded task within that phase. Merge only after the work has been verified against the documentation.

## Commit philosophy

Keep commits focused and logically scoped: one phase, or one task within a phase, per commit wherever practical. Commit messages should describe the documented work completed without implying work from later phases.

## Documentation changes

Do not modify documentation silently. If implementation reveals a genuine inconsistency, flag it explicitly before making a documentation change.

## Development environments

Phase 2 establishes empty project shells only. The selected stable tool versions are:

- Backend: Node.js 24.13.0 LTS, npm 11.6.2, Fastify 5.10.0, TypeScript 6.0.3, ESLint 10.7.0, and Prettier 3.9.5.
- Android: JDK 17, Android Gradle Plugin 9.2.0, Gradle 9.4.1, Kotlin 2.3.21, compile SDK 37, target SDK 37, and minimum SDK 29.
- macOS: Xcode 26.6 and Swift 6.3.3, with a macOS 13.0 deployment target.

### Backend

From `backend/`, run `npm install`, then `npm run build`. Run `npm run lint` and `npm run format` to validate tooling. Start the empty Fastify shell with `npm run start`.

### Android

Install Android SDK platform 37 and use JDK 17. From `android/`, run `./gradlew assembleDebug` to build the empty application shell.

### macOS

Open `macos/MacEcho.xcodeproj` in Xcode and run the `MacEcho` scheme, or build from the repository root with `xcodebuild -project macos/MacEcho.xcodeproj -scheme MacEcho -configuration Debug build`.
