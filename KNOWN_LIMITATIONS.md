# Known Limitations

- `configs/pipelines/*.yaml` `notifications:` block is accepted by the
  schema and parsed by `proteus.config.load_pipeline` but **not executed**
  by `proteus.runner.run_pipeline`. Tracked as the #82 follow-up.
- `.github/workflows/cross-repo-dispatch.yml` does not yet route through
  the runner; owned by #15 / #84 (payload contract first).
- `proteus.runner.discover_dagger_functions` parses the `dagger functions`
  table format. If a future Dagger release changes that format, the
  dry-run drift guard becomes a no-op (tolerant by design) and must be
  updated.
