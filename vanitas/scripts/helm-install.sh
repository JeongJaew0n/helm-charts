#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_DIR="$SCRIPT_DIR/../tekton-ci"

helm upgrade --install vanitas-ci "$CHART_DIR" \
  -f "$CHART_DIR/values.yaml" \
  -f "$CHART_DIR/values-secrets.yaml" \
  -n tekton-pipelines
