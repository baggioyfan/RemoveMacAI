# Contributing

Build and run the self-test, which needs no Xcode project and touches nothing on the system:

```sh
swift build -c release
"$(swift build -c release --show-bin-path)/removemacai" selftest
```

Build the app with `tools/build-app.sh`, which puts `RemoveMacAI.app` in `.build`. A debug build can render every page to PNG without screen-recording permission:

```sh
swift build && REMOVEMACAI_SNAPSHOTS=/tmp/shots .build/debug/removemacai app
```

A new tweak goes in `Sources/removemacai/Tweaks.swift`. Check that macOS still reads its key before adding it, and say how you checked.

Every change RemoveMacAI makes is shown before it happens and can be undone, and a new tweak has to keep that. A tweak that can break something people rely on stays out of the presets.

Keep one change per pull request, and say which macOS version and build you tested on. For a bug, the output of `removemacai status` and `sw_vers` helps most.
