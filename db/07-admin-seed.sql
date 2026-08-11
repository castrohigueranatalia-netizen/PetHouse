-- ============================================================
-- PETHOUSE · Cuenta de administrador de prueba
-- ------------------------------------------------------------
-- Ninguno de los usuarios del seed original (02-seed.sql) tiene rol 'admin' — sin esto no
-- hay forma de probar el panel de administración (GET/POST /api/admin/*, soloAdmin).
--
-- Mismo hash de contraseña que el resto de cuentas demo ('demo123' — ver 02-seed.sql).
--
-- Aplicar después de 06-verificacion-anfitrion.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 07-admin-seed.sql
-- ============================================================

INSERT INTO usuarios (id, nombre, email, telefono, password_hash, rol, verificado)
VALUES (
  '00000000-0000-0000-0000-000000000099',
  'Admin Pethouse',
  'admin@pethouse.co',
  '300 000 0000',
  '$2a$10$wao36cN7mdhvq6OQiVouCeAmS1ftYmQsTl/QblBZIV6qTkTI/0THG',
  'admin',
  TRUE
)
ON CONFLICT (email) DO NOTHING;
