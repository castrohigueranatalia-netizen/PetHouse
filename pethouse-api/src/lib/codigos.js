// ============================================================
// PETHOUSE API · Código de 6 dígitos para restablecer contraseña
//
// Compartido entre routes/auth.js (el código que se manda por correo) y routes/admin.js
// (el PIN que un admin genera a mano tras aprobar una verificación de identidad) — ambos
// insertan en la misma tabla restablecimientos_password, así que necesitan el MISMO hash
// para que POST /auth/restablecer-password pueda validar cualquiera de los dos por igual.
// ============================================================
import { randomInt, createHash } from 'node:crypto'

export function generarCodigo() {
  return String(randomInt(0, 1000000)).padStart(6, '0')
}

export function hashCodigo(codigo) {
  return createHash('sha256').update(codigo).digest('hex')
}
