#!/usr/bin/env bash
set -euo pipefail

bash -n scripts/bai_cuoi_ky_hang.sh
test -f README.md
test -f diagrams/bai_cuoi_ky_hang_flow.puml
grep -q "Nguyễn Thị Thanh Hằng" README.md
grep -q "2300191" README.md
! grep -Eiq "plantuml|silicon" README.md

echo "Kiem tra bai cuoi ky cua Hang thanh cong."
