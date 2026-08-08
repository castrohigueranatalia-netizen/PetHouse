#!/usr/bin/env bash
# ============================================================
# PETHOUSE API · Test de integración (curl contra la API real)
# Requiere: base con seed (ver ../db) y el servidor corriendo.
#   node src/server.js   (o: npm start)
# ============================================================
set -euo pipefail
B="${API_URL:-http://localhost:3001}"
PASS=0; FAIL=0

check() { if [ "$2" = "1" ] || [ "$2" = "true" ]; then PASS=$((PASS+1)); echo "✓ $1"; else FAIL=$((FAIL+1)); echo "✗ $1"; fi; }

echo "=== PETHOUSE API · Test de integración ==="
echo ""

# 1. Health
R=$(curl -s $B/health); check "health responde" "$(echo "$R" | grep -c '"ok":true')"

# 2. Login demo
TOKEN=$(curl -s -X POST $B/api/auth/login -H "Content-Type: application/json" -d '{"email":"cliente@pethouse.co","password":"demo123"}' | python3 -c "import json,sys; print(json.load(sys.stdin).get('accessToken',''))")
check "login demo devuelve token" "$([ -n "$TOKEN" ] && echo true)"

# 3. Login con contraseña mala → 401
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $B/api/auth/login -H "Content-Type: application/json" -d '{"email":"cliente@pethouse.co","password":"mala"}')
check "login con clave mala → 401" "$([ "$CODE" = "401" ] && echo true)"

# 4. Registro nuevo usuario
R=$(curl -s -X POST $B/api/auth/registro -H "Content-Type: application/json" -d '{"nombre":"Test Usuario","email":"test-api@pethouse.co","password":"clave123","telefono":"3000000000","mascotaNombre":"Firulais"}')
check "registro crea usuario" "$(echo "$R" | grep -c '"accessToken"')"

# 5. Búsqueda por tipo+ciudad (URL codificada)
R=$(curl -s "$B/api/hospedajes?tipo=guarderia&ciudad=Bogot%C3%A1")
check "búsqueda guardería Bogotá" "$(echo "$R" | python3 -c "import json,sys; d=json.load(sys.stdin); print(1 if d['total']>=1 else 0)")"

# 6. Búsqueda por radio (PostGIS)
R=$(curl -s "$B/api/hospedajes?lat=4.711&lng=-74.072&radio=6000")
check "búsqueda por radio PostGIS" "$(echo "$R" | python3 -c "import json,sys; d=json.load(sys.stdin); print(1 if d['total']>=1 and 'distancia_m' in d['hospedajes'][0] else 0)")"

# 7. Detalle con reseñas
R=$(curl -s "$B/api/hospedajes/20000000-0000-0000-0000-000000000001")
check "detalle hospedaje" "$(echo "$R" | grep -c 'anfitrion_nombre')"

# 8. Crear reserva
HID="20000000-0000-0000-0000-000000000001"
R=$(curl -s -X POST $B/api/reservas -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{\"hospedaje_id\":\"$HID\",\"desde\":\"2027-01-10\",\"hasta\":\"2027-01-13\",\"mascotas\":1}")
check "crear reserva con total" "$(echo "$R" | grep -c '"codigo"')"

# 9. Doble reserva → 409
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $B/api/reservas -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{\"hospedaje_id\":\"$HID\",\"desde\":\"2027-01-11\",\"hasta\":\"2027-01-12\"}")
check "doble reserva rechazada (409)" "$([ "$CODE" = "409" ] && echo true)"

# 10. Mis reservas
R=$(curl -s $B/api/reservas/mias -H "Authorization: Bearer $TOKEN")
check "mis reservas" "$(echo "$R" | python3 -c "import json,sys; d=json.load(sys.stdin); print(1 if len(d['reservas'])>=1 else 0)")"

# 11. Sin token → 401
CODE=$(curl -s -o /dev/null -w "%{http_code}" $B/api/reservas/mias)
check "sin token → 401" "$([ "$CODE" = "401" ] && echo true)"

# 12. Actividades
R=$(curl -s "$B/api/actividades")
check "actividades listadas" "$(echo "$R" | python3 -c "import json,sys; d=json.load(sys.stdin); print(1 if d['total']>=1 else 0)")"

# 13. Chat: conversación + mensaje + no leídos
CONV=$(curl -s -X POST $B/api/conversaciones -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"anfitrion_id":"00000000-0000-0000-0000-000000000002"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['conversacion']['id'])")
R=$(curl -s -X POST $B/api/conversaciones/$CONV/mensajes -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"texto":"Mensaje de prueba del test"}')
check "enviar mensaje chat" "$(echo "$R" | grep -c 'remitente_id')"

# 14. IA estado
R=$(curl -s $B/api/ia/estado)
check "IA estado" "$(echo "$R" | grep -c '"proveedor":"gemini"')"

# 15. Ruta inexistente → 404
CODE=$(curl -s -o /dev/null -w "%{http_code}" $B/api/no-existe)
check "ruta inexistente → 404" "$([ "$CODE" = "404" ] && echo true)"

echo ""
echo "════════════════════════════════════"
echo "  ✅ $PASS verificaciones pasaron · ❌ $FAIL fallaron"
echo "════════════════════════════════════"
[ "$FAIL" = "0" ] || exit 1
