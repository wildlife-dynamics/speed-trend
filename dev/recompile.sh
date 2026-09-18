#!/bin/bash

flags=$*

pixi update --manifest-path pixi.toml

# (re)initialize dot executable to ensure graphviz is available
pixi run --manifest-path pixi.toml dot -c

echo "recompiling spec.yaml with flags '--clobber ${flags}'"

command="pixi run --manifest-path pixi.toml --locked \
wt-compiler compile --spec spec.yaml \
--pkg-name-prefix=ecoscope-workflows \
--results-env-var=ECOSCOPE_WORKFLOWS_RESULTS \
--clobber ${flags}"

exec $command
