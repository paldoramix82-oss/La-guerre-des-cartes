#!/usr/bin/env bash
# Lance les tests headless. Échoue si un test échoue OU si une erreur de script
# apparaît dans la sortie (les erreurs GDScript n'arrêtent pas le test toutes seules).
# Usage : tests/run.sh [chemin/vers/godot]
set -u
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1
OUT="$("$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1)"
CODE=$?
echo "$OUT" | grep -E "ÉCHEC|SCRIPT ERROR|at: |vérifications" | sort | uniq -c
if echo "$OUT" | grep -q "SCRIPT ERROR"; then
	echo "Erreurs de script détectées."
	exit 1
fi
exit $CODE
