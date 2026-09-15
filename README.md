# speedmap-trend

Ecoscope workflow repository for the Speedmap with GAMM Trends workflow.

## Project Structure

- `spec.yaml`: a list of tasks and their relationships
- `param.yaml`: default configuration
- `layout.json`: default dashboard layout
- `test-cases.yaml`: named parameter sets used by `dev/pytest-cli.sh`
- `pixi.toml`: project configuration including dependencies
- `dev`: scripts required for development
- `ecoscope-workflows-speedmap-workflow`: the compiled workflow (generated, do not edit by hand)

This workflow uses only published task packages (`ecoscope-workflows-ext-ecoscope`,
`ecoscope-workflows-ext-custom`, `ecoscope-workflows-ext-gamm-trend-analysis`) — there
are no custom tasks defined in this repo. If you need a new task, add it to the
relevant shared task package repo and publish it, then depend on it here.

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
