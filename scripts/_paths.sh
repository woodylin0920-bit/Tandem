#!/usr/bin/env bash
# _paths.sh — shared path constants for Tandem scripts; source this file.
# Override any path via environment variable before sourcing.
TANDEM_SHARED_DIR="${TANDEM_SHARED_DIR:-$HOME/.claude-work/shared}"
TANDEM_LESSONS_STAGING="${TANDEM_LESSONS_STAGING:-$HOME/.claude-work/_shared/lessons-staging.md}"
export TANDEM_SHARED_DIR TANDEM_LESSONS_STAGING
