import argparse
import json
import os
import sys
from pathlib import Path
from .config import load_pipeline
from .models import Pipeline, DaggerStage, ScriptStage
from .runner import run_pipeline, discover_dagger_functions


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="proteus")
    sub = p.add_subparsers(dest="cmd", required=True)

    run = sub.add_parser("run")
    run.add_argument("config", type=Path)
    run.add_argument("--service", required=True)
    run.add_argument("--host")
    run.add_argument("--dry-run", action="store_true")

    val = sub.add_parser("validate")
    val.add_argument("path", type=Path)

    sub.add_parser("dump-schema")

    args = p.parse_args(argv)

    if args.cmd == "run":
        pipeline = load_pipeline(args.config)
        if args.dry_run:
            _check_drift(pipeline)
        return run_pipeline(pipeline, service=args.service, host=args.host,
                            dry_run=args.dry_run)

    if args.cmd == "validate":
        files = [args.path] if args.path.is_file() else sorted(args.path.glob("*.yaml"))
        for f in files:
            load_pipeline(f)
            print(f"OK: {f}")
        return 0

    if args.cmd == "dump-schema":
        print(json.dumps(Pipeline.model_json_schema(), indent=2, sort_keys=True))
        return 0
    return 1


def _check_drift(pipeline: Pipeline) -> None:
    known = discover_dagger_functions()
    if known:
        for s in pipeline.stages:
            if isinstance(s, DaggerStage) and s.function not in known:
                raise SystemExit(f"unknown dagger function: {s.function}")
    for s in pipeline.stages:
        if isinstance(s, ScriptStage) and not os.access(s.script, os.X_OK):
            raise SystemExit(f"script not executable: {s.script}")


if __name__ == "__main__":
    sys.exit(main())
