import os
import subprocess
from string import Template
from .config import topo_sort
from .models import Pipeline, DaggerStage, ScriptStage


def _template_ctx(pipeline: Pipeline, service: str) -> dict[str, str]:
    return {
        "name": service,
        "registry": pipeline.registry.base if pipeline.registry else "",
        "tag": os.environ.get("IMAGE_TAG", "latest"),
    }


def _sub(value: str, ctx: dict[str, str]) -> str:
    return Template(value).safe_substitute(ctx)


def _build_argv(stage, ctx: dict[str, str], host: str | None) -> list[str]:
    if isinstance(stage, DaggerStage):
        flat: list[str] = []
        for k, v in stage.args.items():
            flat += [f"--{k}", _sub(v, ctx)]
        return ["dagger", "call", stage.function, *flat]
    assert isinstance(stage, ScriptStage)
    values = [_sub(v, ctx) for v in stage.args]
    if stage.type == "dispatch" and host:
        values = [host, *values[1:]] if values else [host]
    return [stage.script, *values]


def run_pipeline(pipeline: Pipeline, *, service: str, host: str | None = None,
                 dry_run: bool = False) -> int:
    ctx = _template_ctx(pipeline, service)
    name_to_stage = {s.name: s for s in pipeline.stages}
    for stage_name in topo_sort(pipeline):
        stage = name_to_stage[stage_name]
        argv = _build_argv(stage, ctx, host)
        print(f"[{stage.name}] " + " ".join(repr(a) if " " in a else a for a in argv))
        if not dry_run:
            subprocess.run(argv, check=True)
    if pipeline.notifications:
        print("notifications: accepted by schema but not executed — see KNOWN_LIMITATIONS.md")
    return 0


def discover_dagger_functions() -> set[str]:
    """Parse `dagger functions` table output. Tolerant: returns set() on any
    failure (missing CLI, unparseable output) so the drift guard becomes a
    no-op rather than a false positive."""
    try:
        out = subprocess.check_output(["dagger", "functions"], text=True,
                                      stderr=subprocess.DEVNULL)
    except (FileNotFoundError, subprocess.CalledProcessError):
        return set()
    names: set[str] = set()
    for line in out.splitlines()[1:]:
        tok = line.split()
        if tok:
            names.add(tok[0])
    return names
