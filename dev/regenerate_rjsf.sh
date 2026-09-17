#!/bin/bash
# Regenerate ONLY rjsf.json, skipping environment resolution entirely.
#
# Two steps:
#   1. Run wt-registry directly against the ALREADY-INSTALLED compiled
#      workflow env (fast — no pixi solve, no ephemeral environment).
#   2. Feed that registry dump into wt-compiler's schema-generation logic
#      (which needs the root env's wt_compiler/wt_contracts packages) to
#      build the final, spec.yaml-shaped, rjsf-overrides-applied rjsf.json.
#
# Set PYTHONPATH before invoking this to shadow in an unpublished local
# ecoscope checkout (same as dev/recompile.sh) - it's inherited by both
# the wt-registry scan and the wt-compiler schema-generation step below.
#
# Usage: ./dev/regenerate_rjsf.sh

set -e

WORKFLOW_DIR="."
GENERATED_DIR="${WORKFLOW_DIR}/ecoscope-workflows-speedmap-workflow"
REGISTRY_BIN="${GENERATED_DIR}/.pixi/envs/default/bin/wt-registry"
REGISTRY_JSON="/tmp/wt_registry_output.json"

if [ ! -x "$REGISTRY_BIN" ]; then
    echo "Error: $REGISTRY_BIN not found or not executable. Compile the workflow once first (./dev/recompile.sh --install)."
    exit 1
fi

echo "1/2: Dumping task registry from the already-installed env..."
time "$REGISTRY_BIN" --format json \
    --package ecoscope.platform.tasks \
    > "$REGISTRY_JSON"

echo ""
echo "2/2: Building rjsf.json from the registry dump + spec.yaml..."
pixi run --manifest-path pixi.toml python -c "
import json
import ruamel.yaml

from wt_contracts.registry import RegistryOutput
from wt_compiler.spec import KnownTask, Spec, TaskTag, known_tasks
from wt_compiler.compiler import DagCompiler

# --- Step 1: populate known_tasks from the registry dump ---
with open('$REGISTRY_JSON') as f:
    registry_output = RegistryOutput.model_validate_json(f.read())

discovered: dict = {}
for entry in registry_output.entries.values():
    public_module_path = entry.public_module_path
    function_name = entry.function_name
    metadata = entry.metadata
    json_schema = dict(entry.json_schema)
    importable_reference = f'{public_module_path}.{function_name}'
    tags = [TaskTag(t) for t in metadata.tags if t in [tt.value for tt in TaskTag]]

    known_task = KnownTask(
        importable_reference=importable_reference,
        tags=tags,
        registry_ref=0,
        json_schema=json_schema,
        description=metadata.description or None,
    )
    if function_name not in discovered:
        discovered[function_name] = {public_module_path: known_task}
    else:
        known_task.registry_ref = len(discovered[function_name])
        discovered[function_name][public_module_path] = known_task

known_tasks.clear()
known_tasks.update(discovered)

# --- Step 2: load spec.yaml, run only the schema-generation part. ---
yaml = ruamel.yaml.YAML(typ='safe')
with open('${WORKFLOW_DIR}/spec.yaml') as f:
    spec_dict = yaml.load(f)
spec = Spec(**spec_dict)

dc = DagCompiler(
    spec=spec,
    pkg_name_prefix='ecoscope-workflows',
    results_env_var='ECOSCOPE_WORKFLOWS_RESULTS',
)
params_schema_hierarchical = dc.get_params_jsonschema(flat=False)
if spec.rjsf_overrides:
    params_schema_hierarchical = spec.rjsf_overrides.apply_overrides(params_schema_hierarchical)

result = params_schema_hierarchical.model_dump(by_alias=True, exclude_none=True)

from pathlib import Path
out = Path('$GENERATED_DIR') / 'ecoscope_workflows_speedmap_workflow' / 'rjsf.json'
out.write_text(json.dumps(result, indent=2) + '\n')
print('written:', out)
"
