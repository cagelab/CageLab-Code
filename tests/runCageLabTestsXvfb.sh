#!/usr/bin/env bash
# runCageLabTestsXvfb.sh — run the CageLab MATLAB test suite under a virtual
# X display (Xvfb) so PTB-based hardware tests work in GitHub Actions, over
# SSH, or on any headless machine.
#
# Usage:
#   bash tests/runCageLabTestsXvfb.sh                  # run full suite
#   bash tests/runCageLabTestsXvfb.sh "runtests('tests/StartIEDMorphobesTest.m')"
#
# The Xvfb screen must be large enough for the task's windowed debug mode
# (1600x900), so the default is 1920x1080x24.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

matlab_bin="${MATLAB_BIN:-matlab}"
xvfb_screen="${XVFB_SCREEN:-1920x1080x24}"

if [[ $# -gt 0 ]]; then
	matlab_command="$*"
else
	matlab_command="addOptickaToPath; cd('${repo_root}'); addpath('tests'); suite = matlab.unittest.TestSuite.fromFolder('tests'); results = run(suite); if any([results.Failed]); error('CageLab:TestsFailed', 'One or more MATLAB tests failed.'); end"
fi

exec xvfb-run -a -s "-screen 0 ${xvfb_screen}" "$matlab_bin" -batch "$matlab_command"
