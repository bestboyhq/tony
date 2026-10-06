# Tony

System-wide dictation for macOS, on device.

Hold fn, speak, and let go: the text lands where the cursor is.
Speech is recognized on the Neural Engine with NVIDIA Parakeet, so audio never leaves the Mac.
Needs macOS 15 and Apple silicon.

## Build from source

```sh
git clone https://github.com/bestboyhq/tony && cd tony
node scripts/package.ts --debug && open release/Tony.app
```

Needs Xcode 26 and Node 24.

## Contributing

Read [AGENTS.md](AGENTS.md) for the invariants and the code style, and the skill in [`.agents/skills/`](.agents/skills) for the area you touch.
Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org), and every merged `feat` or `fix` ships to users as an in-app update.

## License

[AGPL-3.0](LICENSE)
