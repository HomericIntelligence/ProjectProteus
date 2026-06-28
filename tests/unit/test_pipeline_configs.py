import glob
import os
import pytest
import yaml

PIPELINE_FILES = sorted(glob.glob("configs/pipelines/*.yaml"))
VALID_STAGE_TYPES = {"dagger", "skopeo", "dispatch"}
# Mirror of public @func() methods in dagger/src/index.ts. Update this set
# whenever a new @func() is added to the Proteus class.
VALID_DAGGER_FUNCS = {"build", "test", "lint", "lintShellcheck", "lintTsc"}


def _load(path: str) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def test_at_least_one_pipeline_exists() -> None:
    assert PIPELINE_FILES, (
        "configs/pipelines/ has no YAML — a silent CI pass would be misleading"
    )


@pytest.mark.parametrize("path", PIPELINE_FILES)
def test_pipeline_has_required_top_level_keys(path: str) -> None:
    cfg = _load(path)
    for key in ("name", "stages"):
        assert key in cfg, f"{path} missing top-level key: {key!r}"
    # 'on' is parsed as boolean True by YAML parser
    assert True in cfg, f"{path} missing top-level key 'on'"


@pytest.mark.parametrize("path", PIPELINE_FILES)
def test_pipeline_stages_have_valid_types(path: str) -> None:
    cfg = _load(path)
    for stage in cfg["stages"]:
        assert "type" in stage, f"{path}: stage {stage.get('name')!r} missing 'type'"
        assert stage["type"] in VALID_STAGE_TYPES, (
            f"{path}: stage {stage.get('name')!r} has invalid type "
            f"{stage['type']!r}; expected one of {sorted(VALID_STAGE_TYPES)}"
        )


@pytest.mark.parametrize("path", PIPELINE_FILES)
def test_dagger_stages_reference_known_functions(path: str) -> None:
    cfg = _load(path)
    for stage in cfg["stages"]:
        if stage["type"] != "dagger":
            continue
        assert "function" in stage, (
            f"{path}: dagger stage {stage.get('name')!r} missing 'function'"
        )
        assert stage["function"] in VALID_DAGGER_FUNCS, (
            f"{path}: dagger stage references unknown function "
            f"{stage['function']!r}; expected one of {sorted(VALID_DAGGER_FUNCS)}"
        )


@pytest.mark.parametrize("path", PIPELINE_FILES)
def test_script_stages_reference_existing_scripts(path: str) -> None:
    cfg = _load(path)
    for stage in cfg["stages"]:
        if stage["type"] not in ("skopeo", "dispatch"):
            continue
        assert "script" in stage, (
            f"{path}: {stage['type']} stage {stage.get('name')!r} "
            f"missing 'script' key"
        )
        assert os.path.isfile(stage["script"]), (
            f"{path}: stage {stage['name']!r} references missing script "
            f"{stage['script']!r}"
        )
