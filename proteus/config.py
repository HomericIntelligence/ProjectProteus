from pathlib import Path
import yaml
from .models import Pipeline


def load_pipeline(path: Path) -> Pipeline:
    raw = yaml.safe_load(path.read_text())
    pipeline = Pipeline.model_validate(raw, from_attributes=False)
    _check_depends_on(pipeline)
    return pipeline


def topo_sort(pipeline: Pipeline) -> list[str]:
    deps = {s.name: list(s.depends_on) for s in pipeline.stages}
    order: list[str] = []
    remaining = dict(deps)
    while remaining:
        ready = sorted(n for n, ds in remaining.items() if not ds)
        if not ready:
            raise ValueError(f"cycle detected among: {sorted(remaining)}")
        order.extend(ready)
        for n in ready:
            del remaining[n]
        for n in remaining:
            remaining[n] = [d for d in remaining[n] if d not in ready]
    return order


def _check_depends_on(p: Pipeline) -> None:
    names = {s.name for s in p.stages}
    for s in p.stages:
        for d in s.depends_on:
            if d not in names:
                raise ValueError(f"stage '{s.name}' depends on unknown stage '{d}'")
