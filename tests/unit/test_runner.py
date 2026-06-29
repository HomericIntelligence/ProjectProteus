import pytest
from pathlib import Path
from unittest.mock import patch, Mock
from proteus.config import load_pipeline
from proteus.runner import _build_argv, run_pipeline, discover_dagger_functions
from proteus.models import DaggerStage, ScriptStage


def test_build_argv_dagger():
    """Dagger stage args are flattened into --flag value pairs."""
    stage = DaggerStage(
        name="build",
        type="dagger",
        function="build",
        args={"context": ".", "tag": "staging"},
    )
    argv = _build_argv(stage, {"name": "test", "registry": "", "tag": "latest"}, None)
    assert argv == ["dagger", "call", "build", "--context", ".", "--tag", "staging"]


def test_build_argv_skopeo():
    """Skopeo stage args are positional list tokens."""
    stage = ScriptStage(
        name="promote",
        type="skopeo",
        script="scripts/promote-image.sh",
        args=[
            "ghcr.io/homeric-intelligence/achaean-fleet:staging",
            "ghcr.io/homeric-intelligence/achaean-fleet:latest",
        ],
    )
    argv = _build_argv(stage, {"name": "test", "registry": "", "tag": "latest"}, None)
    assert argv == [
        "scripts/promote-image.sh",
        "ghcr.io/homeric-intelligence/achaean-fleet:staging",
        "ghcr.io/homeric-intelligence/achaean-fleet:latest",
    ]


def test_dispatch_host_override():
    """Host override replaces the first positional arg of a dispatch stage."""
    stage = ScriptStage(
        name="dispatch-apply",
        type="dispatch",
        script="scripts/dispatch-apply.sh",
        args=["hermes"],
    )
    argv = _build_argv(stage, {"name": "test", "registry": "", "tag": "latest"}, "gandalf")
    assert argv == ["scripts/dispatch-apply.sh", "gandalf"]


def test_args_with_spaces_are_safe():
    """Args containing spaces are single tokens in argv (not shell-split)."""
    stage = DaggerStage(
        name="test",
        type="dagger",
        function="test",
        args={"command": "my image"},
    )
    argv = _build_argv(stage, {"name": "test", "registry": "", "tag": "latest"}, None)
    assert argv == ["dagger", "call", "test", "--command", "my image"]


def test_undefined_template_var_is_literal():
    """Undefined template variables are left as literal strings."""
    stage = DaggerStage(
        name="test",
        type="dagger",
        function="test",
        args={"tag": "$undefined"},
    )
    argv = _build_argv(stage, {"name": "test", "registry": "", "tag": "latest"}, None)
    # safe_substitute leaves unknown vars as-is
    assert argv == ["dagger", "call", "test", "--tag", "$undefined"]


def test_dry_run_skips_subprocess(monkeypatch):
    """Dry-run mode does not call subprocess.run."""
    mock_run = Mock()
    monkeypatch.setattr("proteus.runner.subprocess.run", mock_run)

    pipeline = load_pipeline(Path("configs/pipelines/achaean-fleet.yaml"))
    run_pipeline(pipeline, service="achaean-fleet", dry_run=True)

    mock_run.assert_not_called()


def test_dry_run_drift_guard_unknown_function(monkeypatch):
    """Dry-run drift guard rejects unknown dagger functions when dagger is available."""
    from proteus.__main__ import _check_drift

    # Mock discover_dagger_functions to return only 'build', not 'test'
    def mock_discover():
        return {"build"}

    monkeypatch.setattr("proteus.__main__.discover_dagger_functions", mock_discover)

    pipeline = load_pipeline(Path("configs/pipelines/achaean-fleet.yaml"))
    # 'test' is not in the discovered set, should raise
    with pytest.raises(SystemExit, match="unknown dagger function"):
        _check_drift(pipeline)


def test_dry_run_drift_guard_skipped_when_dagger_missing(monkeypatch):
    """Dry-run drift guard is a no-op when dagger is missing."""
    from proteus.__main__ import _check_drift

    # Mock to return empty set (dagger missing)
    monkeypatch.setattr("proteus.__main__.discover_dagger_functions", lambda: set())

    pipeline = load_pipeline(Path("configs/pipelines/achaean-fleet.yaml"))
    # Should not raise even though 'test' is not discovered (set is empty → no-op)
    _check_drift(pipeline)
