# speedmap-trend

Ecoscope workflow repository for the Speedmap with Trend Analysis workflow.
Classifies EarthRanger subject movement by speed and fits a trend model
(Linear, GLM, GAM, or GAMM) to mean speed over time.

## Project Structure

- `spec.yaml`: a list of tasks and their relationships
- `param.yaml`: default configuration
- `layout.json`: default dashboard layout
- `test-cases.yaml`: named parameter sets used by the compiled workflow's
  own mock-io test suite (`pixi run --environment test test-cli-sequential-mock-io`, etc.)
- `pixi.toml`: project configuration including dependencies
- `dev`: scripts required for development
- `ecoscope-workflows-speedmap-workflow`: the compiled workflow (generated, do not edit by hand)

This workflow depends on `ecoscope-platform` (published) — there are no
custom task packages in this repo. If you need a new task, add it to
`ecoscope` and publish it, then depend on it here.

## Trend Analysis

The `Trend Analysis` step lets you pick one of four regression models
(Linear, GLM, GAM, GAMM), fit to mean speed per `Trend Time Bucket`. Every
group (from `Group Data`'s grouper, e.g. Subject Name) still gets its own
trend chart in the dashboard - but GAMM is wired differently from the other
three under the hood, for the same reason as wt-hansen-deforestation's
Trend Analysis: a random effect needs more than one group's data in the same
fit to estimate any cross-group variance from.

Linear/GLM/GAM each **fit independently per group**: `trend_fit`/
`trend_predictions` are `mapvalues`'d over `speed_trends`'s per-group output.

GAMM **fits once, combined across every group** (`speed_trends_combined` via
`concat_dataframes`, then `trend_fit_combined`), using a `name` column
tagged onto each group's rows by `rename_value_grouper_columns_to_name`
(renames whichever `Group Data` grouper's column - e.g. `subject_name` - to
the literal `name` column `fit_trend_model`/`predict_trend_model` read as
the site label). `trend_groupby_columns` decides whether `speed_trends`
groups by the time bucket alone (no grouper active - GAMM falls back to a
single degenerate site) or by the time bucket plus `name`. As with Hansen,
`predict_trend_model`'s `dataframe` parameter then pulls each group's own
group-specific prediction back out of the shared combined fit, so the chart
still shows one line per group.

Combined-fit pooling is most meaningful when grouping by Subject Name (real
repeated-measures data across individual animals); grouping by a coarser
attribute (Subject Subtype, Subject Sex) or leaving groupers empty pools
across whatever coarser groups are being viewed side by side instead.

Speedmap's per-bucket, per-group series are often much shorter and sparser
than Hansen's yearly regional series (e.g. a subject tracked for only a
few weeks) - `spec.yaml`'s `rjsf-overrides` lower `GamSplineSettings`/
`GammSplineSettings`'s degrees-of-freedom defaults accordingly, and the
`Trend Time Bucket` field lets a user switch to Day or Week bucketing for
short tracking periods. Note that these lowered *defaults* only affect the
UI form - `param.yaml`/`test-cases.yaml` must set the same fields explicitly
since a headless run without form defaults otherwise falls back to
`ecoscope`'s own library-wide pydantic defaults.

## Workflow Development

1. Update the workflow:
   - `spec.yaml`: a list of tasks and their relationships
   - `param.yaml`: default configuration
   - `layout.json`: update the default dashboard layout if your workflow generates a dashboard

2. Compile the workflow:
   ```bash
   pixi run compile-speedmap
   ```

   This generates `ecoscope-workflows-speedmap-workflow` with the compiled workflow.

   After updating the spec, recompile with:
   ```bash
   pixi run recompile-speedmap
   ```

   To iterate on `rjsf-overrides`/UI schema alone without a full recompile
   (no environment resolution, seconds instead of minutes), use:
   ```bash
   PYTHONPATH=/absolute/path/to/local/ecoscope ./dev/regenerate_rjsf.sh
   ```

3. Test the workflow. First set up your output directory:
   ```bash
   mkdir -p /tmp/workflows/speedmap-trend/output
   export ECOSCOPE_WORKFLOWS_RESULTS=file:///tmp/workflows/speedmap-trend/output
   ```
   Then run it:
   ```bash
   cd ecoscope-workflows-speedmap-workflow
   pixi run ecoscope-workflows-speedmap-workflow run --config-file ../param.yaml --execution-mode sequential --mock-io
   ```
   Results land in `/tmp/workflows/speedmap-trend/output/result.json`.

   Without real EarthRanger credentials, use the compiled workflow's own
   mock-io test suite (mocks `get_subjectgroup_observations`/
   `get_spatial_features_group` against `test-cases.yaml`'s named cases):
   ```bash
   cd ecoscope-workflows-speedmap-workflow
   pixi run --environment test python -m pytest -v tests/test_results.py \
     -k 'cli and sequential and mock-io' --case all-grouper --case value-grouper
   ```

## Troubleshoot

1. Task not registered
   Clean up pixi caches by:
   ```bash
   pixi clean cache
   rm -rf .pixi
   rm -rf pixi.lock
   pixi update
   ```
   And compile again.

## Additional Resources

- [Ecoscope Core Library](https://github.com/wildlife-dynamics/ecoscope)
- [Pixi Documentation](https://pixi.sh/latest/)
