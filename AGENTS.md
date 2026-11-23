# Moorings lab

This folder is a self-contained Java 21 Maven project. Treat it as the whole
repository for every task here.

The `AGENTS.md` at the root of the enclosing repository describes a different
project. Its rules (cockpit store, git-crypt, slide decks, writing voice) do not apply
to anything in this folder. Ignore them here.

- Work only inside this folder. Do not read or change files above it.
- Tickets are in `tickets/`. The hooks in `.github/hooks/lab.json` decide when work is
  finished.
- Build and test with the Maven wrapper in this folder: `./mvnw` on macOS and Linux,
  `.\mvnw.cmd` on Windows.
