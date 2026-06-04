"""Integration tests for configs/pipelines/*.yaml consumption.

#82 regression seed: production code does not currently read these configs.
The xfail-strict test below pins that contract and turns red the day
production code starts referencing the path — at which point flip
strict=False (or delete the xfail) per the inline note.
"""
import glob
import pathlib
import subprocess

import pytest
import yaml

REPO = pathlib.Path(__file__).resolve().parents[2]
CONFIGS = sorted(glob.glob(str(REPO / "configs" / "pipelines" / "*.yaml")))


@pytest.mark.parametrize("cfg_path", CONFIGS)
def test_pipeline_config_parses(cfg_path):
    data = yaml.safe_load(pathlib.Path(cfg_path).read_text())
    assert "name" in data
    assert "stages" in data and isinstance(data["stages"], list) and data["stages"]


@pytest.mark.parametrize("cfg_path", CONFIGS)
def test_pipeline_stage_scripts_exist(cfg_path):
    """Every stage referencing a script must point at a real file."""
    data = yaml.safe_load(pathlib.Path(cfg_path).read_text())
    for stage in data["stages"]:
        script = stage.get("script")
        if script:
            assert (REPO / script).is_file(), f"{cfg_path}: missing {script}"


# NOTE FOR FUTURE CONTRIBUTORS:
#   strict=True means: if this test ever PASSES, the suite FAILS.
#   This is intentional — it pins the #82 contract. When production code
#   starts consuming configs/pipelines/*.yaml, flip strict=False or remove
#   the xfail marker. Do NOT delete the test body.
@pytest.mark.xfail(
    reason="#82: production code does not yet consume configs/pipelines/*.yaml. "
    "Strict=True forces a failure if this ever passes — see note above.",
    strict=True,
)
@pytest.mark.parametrize("cfg_path", CONFIGS)
def test_pipeline_config_is_consumed_by_production_code(cfg_path):
    cfg_rel = pathlib.Path(cfg_path).relative_to(REPO).as_posix()
    result = subprocess.run(
        ["git", "grep", "-l", "--", cfg_rel, "--", "dagger/src/", "scripts/"],
        cwd=REPO, capture_output=True, text=True,
    )
    consumers = [ln for ln in result.stdout.splitlines() if not ln.endswith(".test.ts")]
    assert consumers, f"No production consumer references {cfg_rel}"
