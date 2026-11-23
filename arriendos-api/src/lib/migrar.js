// ============================================================
// ARRIENDOS CARTAGENA API · Crea el esquema y aplica migraciones
// ------------------------------------------------------------
// Si la base de datos está vacía (recién creada, por ejemplo en
// Render), aplica db/01-esquema.sql y db/02-seed.sql automáticamente.
// Si ya tiene las tablas, no las vuelve a crear — pero sí aplica, en
// cada arranque, los pequeños cambios de esquema posteriores (como
// agregar el estado "pagada"), de forma segura para repetir.
// ============================================================
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { pool } from '../config.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const DB_DIR = path.join(__dirname, '..', '..', 'db')

export async function asegurarEsquema() {
  const { rows } = await pool.query("SELECT to_regclass('public.apartamentos') AS existe")
  if (!rows[0].existe) {
    console.log('⚙ Base de datos vacía: creando esquema y datos iniciales...')
    const esquema = fs.readFileSync(path.join(DB_DIR, '01-esquema.sql'), 'utf8')
    await pool.query(esquema)
    const seed = fs.readFileSync(path.join(DB_DIR, '02-seed.sql'), 'utf8')
    await pool.query(seed)
    console.log('✔ Esquema y datos iniciales creados (usuario y 7 apartamentos)')
  }

  await aplicarMigraciones()
}

// Cambios de esquema posteriores a la primera versión. Cada uno debe poder
// correr de nuevo sin romper nada (por eso las verificaciones "si ya existe,
// no hacer nada" antes de cada cambio).
async function aplicarMigraciones() {
  // Estado "pagada": una reserva confirmada con el pago ya recibido.
  await pool.query(`ALTER TYPE estado_reserva ADD VALUE IF NOT EXISTS 'pagada'`)

  // La restricción anti-doble-reserva debe bloquear tanto 'confirmada' como
  // 'pagada' (las dos ocupan el apartamento); se recrea solo si hace falta.
  const { rows } = await pool.query(
    `SELECT pg_get_constraintdef(oid) AS definicion FROM pg_constraint WHERE conname = 'chk_no_solape'`
  )
  const definicionActual = rows[0]?.definicion || ''
  if (definicionActual && !definicionActual.includes("'pagada'")) {
    console.log('⚙ Actualizando la restricción anti-doble-reserva para incluir "pagada"...')
    await pool.query(`ALTER TABLE reservas DROP CONSTRAINT chk_no_solape`)
    await pool.query(`
      ALTER TABLE reservas ADD CONSTRAINT chk_no_solape
        EXCLUDE USING gist (
          apartamento_id WITH =,
          daterange(checkin, checkout) WITH &&
        ) WHERE (estado IN ('confirmada', 'pagada'))
    `)
    console.log('✔ Restricción actualizada')
  }

  // Notificaciones push de pago pendiente (columna + tabla de suscripciones).
  await pool.query(`ALTER TABLE reservas ADD COLUMN IF NOT EXISTS recordatorio_pago_enviado_en TIMESTAMPTZ`)
  await pool.query(`
    CREATE TABLE IF NOT EXISTS push_suscripciones (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      endpoint    TEXT NOT NULL UNIQUE,
      p256dh      TEXT NOT NULL,
      auth        TEXT NOT NULL,
      creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)

  // Coordinación de limpieza: personal (niñas de limpieza) + tareas asignadas
  // por apartamento/fecha/hora. CREATE TYPE no admite "IF NOT EXISTS", por
  // eso se revisa antes en pg_type.
  const { rows: tipoLimpiezaExiste } = await pool.query(
    `SELECT 1 FROM pg_type WHERE typname = 'estado_limpieza'`
  )
  if (!tipoLimpiezaExiste.length) {
    await pool.query(`CREATE TYPE estado_limpieza AS ENUM ('pendiente', 'lista')`)
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS personal_limpieza (
      id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      nombre     TEXT NOT NULL,
      telefono   TEXT,
      activo     BOOLEAN NOT NULL DEFAULT TRUE,
      creado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)

  await pool.query(`
    CREATE TABLE IF NOT EXISTS tareas_limpieza (
      id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      apartamento_id  UUID NOT NULL REFERENCES apartamentos(id) ON DELETE CASCADE,
      personal_id     UUID REFERENCES personal_limpieza(id) ON DELETE SET NULL,
      fecha           DATE NOT NULL,
      hora            TIME,
      estado          estado_limpieza NOT NULL DEFAULT 'pendiente',
      notas           TEXT,
      creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
      actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)
  await pool.query(`ALTER TABLE tareas_limpieza ADD COLUMN IF NOT EXISTS valor NUMERIC(10,2) CHECK (valor IS NULL OR valor >= 0)`)
  await pool.query(`CREATE INDEX IF NOT EXISTS idx_tareas_limpieza_fecha ON tareas_limpieza (fecha)`)
  await pool.query(`CREATE INDEX IF NOT EXISTS idx_tareas_limpieza_apartamento ON tareas_limpieza (apartamento_id)`)
  await pool.query(`DROP TRIGGER IF EXISTS trg_tareas_limpieza_actualizado_en ON tareas_limpieza`)
  await pool.query(`
    CREATE TRIGGER trg_tareas_limpieza_actualizado_en
      BEFORE UPDATE ON tareas_limpieza
      FOR EACH ROW EXECUTE FUNCTION tocar_actualizado_en()
  `)

  // Si la tabla personal_limpieza quedó vacía (base ya existente antes de
  // esta migración), se siembran las 5 niñas iniciales igual que en el seed.
  const { rows: personalExistente } = await pool.query('SELECT 1 FROM personal_limpieza LIMIT 1')
  if (!personalExistente.length) {
    await pool.query(`
      INSERT INTO personal_limpieza (nombre, telefono) VALUES
        ('María', '3000000001'), ('Carmen', '3000000002'), ('Luz Dary', '3000000003'),
        ('Yolanda', '3000000004'), ('Esperanza', '3000000005')
    `)
  }

  // Lavandería: niñas asignadas al local cada día (bloquea limpieza ese día
  // y viceversa) + pedidos de ropa.
  const { rows: tipoPedidoExiste } = await pool.query(
    `SELECT 1 FROM pg_type WHERE typname = 'estado_pedido_lavanderia'`
  )
  if (!tipoPedidoExiste.length) {
    await pool.query(`CREATE TYPE estado_pedido_lavanderia AS ENUM ('en_proceso', 'entregado')`)
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS turnos_lavanderia (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      personal_id UUID NOT NULL REFERENCES personal_limpieza(id) ON DELETE CASCADE,
      fecha       DATE NOT NULL,
      creado_en   TIMESTAMPTZ NOT NULL DEFAULT now(),
      CONSTRAINT uq_turno_lavanderia UNIQUE (personal_id, fecha)
    )
  `)
  await pool.query(`CREATE INDEX IF NOT EXISTS idx_turnos_lavanderia_fecha ON turnos_lavanderia (fecha)`)

  await pool.query(`
    CREATE TABLE IF NOT EXISTS pedidos_lavanderia (
      id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      cliente_nombre   TEXT,
      cliente_telefono TEXT,
      num_prendas      SMALLINT CHECK (num_prendas IS NULL OR num_prendas > 0),
      fecha_ingreso    DATE NOT NULL,
      fecha_entrega    DATE,
      valor            NUMERIC(10,2) CHECK (valor IS NULL OR valor >= 0),
      estado           estado_pedido_lavanderia NOT NULL DEFAULT 'en_proceso',
      notas            TEXT,
      creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
      actualizado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)
  await pool.query(`CREATE INDEX IF NOT EXISTS idx_pedidos_lavanderia_fecha_ingreso ON pedidos_lavanderia (fecha_ingreso)`)
  await pool.query(`DROP TRIGGER IF EXISTS trg_pedidos_lavanderia_actualizado_en ON pedidos_lavanderia`)
  await pool.query(`
    CREATE TRIGGER trg_pedidos_lavanderia_actualizado_en
      BEFORE UPDATE ON pedidos_lavanderia
      FOR EACH ROW EXECUTE FUNCTION tocar_actualizado_en()
  `)

  // Tipo de servicio (con precio distinto según el tipo) y quién atendió el pedido.
  const { rows: tipoServicioExiste } = await pool.query(
    `SELECT 1 FROM pg_type WHERE typname = 'tipo_servicio_lavanderia'`
  )
  if (!tipoServicioExiste.length) {
    await pool.query(`CREATE TYPE tipo_servicio_lavanderia AS ENUM ('lavado', 'planchado', 'lavado_y_planchado')`)
  }
  await pool.query(`ALTER TABLE pedidos_lavanderia ADD COLUMN IF NOT EXISTS tipo_servicio tipo_servicio_lavanderia NOT NULL DEFAULT 'lavado'`)
  await pool.query(`ALTER TABLE pedidos_lavanderia ADD COLUMN IF NOT EXISTS personal_id UUID REFERENCES personal_limpieza(id) ON DELETE SET NULL`)

  // Ítems por pedido (varias prendas/categorías en una misma factura, cada
  // una con su cantidad y valor por unidad). num_prendas/valor del pedido
  // pasan a ser el total ya sumado de sus ítems.
  const { rows: tipoPrendaExiste } = await pool.query(
    `SELECT 1 FROM pg_type WHERE typname = 'tipo_prenda_lavanderia'`
  )
  if (!tipoPrendaExiste.length) {
    await pool.query(`CREATE TYPE tipo_prenda_lavanderia AS ENUM ('ropa', 'sabanas', 'lenceria_cama', 'otros')`)
  }
  await pool.query(`
    CREATE TABLE IF NOT EXISTS items_pedido_lavanderia (
      id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      pedido_id       UUID NOT NULL REFERENCES pedidos_lavanderia(id) ON DELETE CASCADE,
      tipo_prenda     tipo_prenda_lavanderia NOT NULL DEFAULT 'otros',
      cantidad        SMALLINT NOT NULL CHECK (cantidad > 0),
      valor_unitario  NUMERIC(10,2) NOT NULL CHECK (valor_unitario >= 0),
      subtotal        NUMERIC(12,2) GENERATED ALWAYS AS (cantidad * valor_unitario) STORED,
      creado_en       TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)
  await pool.query(`CREATE INDEX IF NOT EXISTS idx_items_pedido_lavanderia_pedido ON items_pedido_lavanderia (pedido_id)`)

  // Pedidos de antes de este cambio (con num_prendas/valor sueltos y sin
  // ítems todavía): se les crea un ítem "Otros" con esos mismos datos, para
  // no perder la información ya cargada.
  await pool.query(`
    INSERT INTO items_pedido_lavanderia (pedido_id, tipo_prenda, cantidad, valor_unitario)
    SELECT pl.id, 'otros', GREATEST(COALESCE(pl.num_prendas, 1), 1),
           ROUND(COALESCE(pl.valor, 0) / GREATEST(COALESCE(pl.num_prendas, 1), 1), 2)
      FROM pedidos_lavanderia pl
     WHERE NOT EXISTS (SELECT 1 FROM items_pedido_lavanderia i WHERE i.pedido_id = pl.id)
       AND (pl.valor IS NOT NULL OR pl.num_prendas IS NOT NULL)
  `)

  // Productos de lavandería (inventario): jabón, desmanchante, vinagre, etc.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS productos_lavanderia (
      id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      nombre          TEXT NOT NULL,
      cantidad        NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
      unidad          TEXT NOT NULL DEFAULT 'unidades',
      valor_unitario  NUMERIC(10,2) CHECK (valor_unitario IS NULL OR valor_unitario >= 0),
      creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
      actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)
  await pool.query(`DROP TRIGGER IF EXISTS trg_productos_lavanderia_actualizado_en ON productos_lavanderia`)
  await pool.query(`
    CREATE TRIGGER trg_productos_lavanderia_actualizado_en
      BEFORE UPDATE ON productos_lavanderia
      FOR EACH ROW EXECUTE FUNCTION tocar_actualizado_en()
  `)

  const { rows: productosExistentes } = await pool.query('SELECT 1 FROM productos_lavanderia LIMIT 1')
  if (!productosExistentes.length) {
    await pool.query(`
      INSERT INTO productos_lavanderia (nombre, cantidad, unidad, valor_unitario) VALUES
        ('Jabón en polvo', 10, 'kg', 8000),
        ('Desmanchante', 5, 'litros', 12000),
        ('Vinagre', 8, 'litros', 4000),
        ('Suavizante', 6, 'litros', 9000)
    `)
  }

  // Historial de compras por producto (cantidad/valor_unitario del producto
  // pasan a calcularse a partir de aquí; ya no se editan directamente).
  await pool.query(`
    CREATE TABLE IF NOT EXISTS compras_producto_lavanderia (
      id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      producto_id     UUID NOT NULL REFERENCES productos_lavanderia(id) ON DELETE CASCADE,
      fecha_compra    DATE NOT NULL,
      cantidad        NUMERIC(10,2) NOT NULL CHECK (cantidad > 0),
      valor_unitario  NUMERIC(10,2) NOT NULL CHECK (valor_unitario >= 0),
      valor_total     NUMERIC(12,2) GENERATED ALWAYS AS (cantidad * valor_unitario) STORED,
      notas           TEXT,
      creado_en       TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)
  await pool.query(`CREATE INDEX IF NOT EXISTS idx_compras_producto_lavanderia_producto ON compras_producto_lavanderia (producto_id)`)

  // Productos de antes de este cambio (con cantidad/valor_unitario puestos
  // directamente, sin compras todavía): se les crea una compra inicial con
  // esos mismos datos, para no perder lo que ya tenían cargado.
  await pool.query(`
    INSERT INTO compras_producto_lavanderia (producto_id, fecha_compra, cantidad, valor_unitario)
    SELECT p.id, p.creado_en::date, p.cantidad, COALESCE(p.valor_unitario, 0)
      FROM productos_lavanderia p
     WHERE p.cantidad > 0
       AND NOT EXISTS (SELECT 1 FROM compras_producto_lavanderia c WHERE c.producto_id = p.id)
  `)

  // Más datos por reserva: hora de entrada/salida (aparte de la fecha) y si
  // ya dieron abono (y cuánto).
  await pool.query(`ALTER TABLE reservas ADD COLUMN IF NOT EXISTS hora_checkin TIME`)
  await pool.query(`ALTER TABLE reservas ADD COLUMN IF NOT EXISTS hora_checkout TIME`)
  const yaTieneAbono = await pool.query(`SELECT 1 FROM information_schema.columns WHERE table_name = 'reservas' AND column_name = 'valor_abono'`)
  if (!yaTieneAbono.rows.length) {
    await pool.query(`ALTER TABLE reservas ADD COLUMN valor_abono NUMERIC(10,2) CHECK (valor_abono IS NULL OR valor_abono >= 0)`)
  }
}

