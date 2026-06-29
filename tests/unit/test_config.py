import pytest
from pathlib import Path
from pydantic import ValidationError
from proteus.config import load_pipeline, topo_sort


def test_loads_achaean_fleet():
    """Load and topo-sort the canonical pipeline config."""
    pipeline = load_pipeline(Path("configs/pipelines/achaean-fleet.yaml"))
    assert pipeline.name == "achaean-fleet"
    order = topo_sort(pipeline)
    assert order == ["build", "test", "promote", "dispatch-apply"]


def test_empty_stages_allowed():
    """Pipeline with empty stages list is allowed."""
    pipeline = load_pipeline(Path("tests/fixtures/no-stages.yaml"))
    assert pipeline.stages == []


def test_dagger_stage_requires_function():
    """Dagger stages must have a function field."""
    with pytest.raises(ValidationError):
        load_pipeline(Path("tests/fixtures/dagger-no-function.yaml"))


def test_skopeo_stage_uses_list_args():
    """Skopeo stages have args as a list, not dict."""
    pipeline = load_pipeline(Path("configs/pipelines/achaean-fleet.yaml"))
    promote = next(s for s in pipeline.stages if s.name == "promote")
    assert promote.type == "skopeo"
    assert isinstance(promote.args, list)
    assert len(promote.args) == 2


def test_dangling_depends_on_rejected():
    """Stage cannot depend on a nonexistent stage."""
    with pytest.raises(ValueError, match="unknown stage"):
        load_pipeline(Path("tests/fixtures/dangling-depends-on.yaml"))


def test_cyclic_depends_on_rejected():
    """Cyclic dependencies are rejected by topo_sort."""
    pipeline = load_pipeline(Path("tests/fixtures/cyclic-depends-on.yaml"))
    with pytest.raises(ValueError, match="cycle"):
        topo_sort(pipeline)


def test_duplicate_stage_names_rejected():
    """Two stages with the same name are rejected."""
    with pytest.raises(ValidationError):
        load_pipeline(Path("tests/fixtures/duplicate-stage-names.yaml"))


def test_notifications_block_accepted_but_ignored():
    """Notifications block is parsed but not executed."""
    pipeline = load_pipeline(Path("configs/pipelines/achaean-fleet.yaml"))
    assert pipeline.notifications is not None
    assert len(pipeline.notifications.on_failure) > 0
    assert len(pipeline.notifications.on_success) > 0
