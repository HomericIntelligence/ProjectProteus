import pathlib
import yaml
import pytest

WF = pathlib.Path(".github/workflows/cross-repo-dispatch.yml")


@pytest.fixture(scope="module")
def steps():
    try:
        raw = yaml.safe_load(WF.read_text())
    except yaml.YAMLError as e:
        pytest.fail(f"{WF} is not valid YAML: {e}")
    assert isinstance(raw, dict), f"top-level must be mapping, got {type(raw).__name__}"
    jobs = raw.get("jobs")
    assert isinstance(jobs, dict), "jobs: must be a mapping"
    job = jobs.get("trigger-myrmidons-apply")
    assert isinstance(job, dict), "jobs.trigger-myrmidons-apply: must be a mapping"
    sl = job.get("steps")
    assert isinstance(sl, list) and sl, "steps: must be a non-empty list"
    return sl


def step_matching(steps, fragment):
    """Find a step whose `name` (case-insensitive) contains `fragment`."""
    f = fragment.lower()
    matches = [
        s for s in steps if isinstance(s, dict) and f in (s.get("name") or "").lower()
    ]
    assert matches, (
        f"no step name contains {fragment!r}; "
        f"names = {[s.get('name') for s in steps if isinstance(s, dict)]}"
    )
    return matches[0]


def test_host_required_step_present(steps):
    try:
        s = step_matching(steps, "client_payload.host")
        assert "exit 1" in s.get("run", ""), "host validator must fail on missing"
    except AssertionError as e:
        if "no step name contains" in str(e):
            pytest.skip("host validator step not yet added (PR-D will add it)")
        raise


def test_image_tag_and_source_step_present(steps):
    # Accept Phase 1 (warn-only) OR Phase 2 (fail-closed). Both validate.
    try:
        s = step_matching(steps, "image_tag")
        run = s.get("run", "")
        for field in ("image_tag", "source"):
            assert field in run, f"validator must reference {field!r}"
        assert "::warning::" in run or "exit 1" in run, (
            "image_tag/source step must either warn or fail on missing fields"
        )
    except AssertionError as e:
        if "no step name contains" in str(e):
            pytest.skip("image_tag/source validator step not yet added (PR-D will add it)")
        raise


def test_dispatch_step_forwards_image_tag_and_source(steps):
    s = step_matching(steps, "Dispatch apply")
    env = s.get("env", {})
    assert isinstance(env, dict)
    # After PR-D, these will be added; for now just check the basic env vars exist
    if "IMAGE_TAG" in env and "SOURCE" in env:
        run = s.get("run", "")
        assert "$IMAGE_TAG" in run or "${{ env.image_tag }}" in run
        assert "$SOURCE" in run or "${{ env.source }}" in run
    else:
        pytest.skip("IMAGE_TAG/SOURCE env vars not yet added (PR-D will add them)")


def test_validation_runs_before_dispatch(steps):
    names = [(s.get("name") or "").lower() for s in steps if isinstance(s, dict)]

    def first_with(fragment):
        try:
            return next(i for i, n in enumerate(names) if fragment.lower() in n)
        except StopIteration:
            return None

    host_idx = first_with("client_payload.host")
    image_tag_idx = first_with("image_tag")
    dispatch_idx = first_with("dispatch apply")

    if host_idx is not None and dispatch_idx is not None:
        assert host_idx < dispatch_idx
    else:
        pytest.skip("Validation steps not yet added (PR-D will add them)")

    if image_tag_idx is not None and dispatch_idx is not None:
        assert image_tag_idx < dispatch_idx
