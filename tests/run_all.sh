#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for test_file in "$project_dir"/tests/*_test.gd; do
	test_name="${test_file#"$project_dir"/}"
	printf '\n==> %s\n' "$test_name"
	godot --headless --path "$project_dir" --script "res://$test_name"
done
