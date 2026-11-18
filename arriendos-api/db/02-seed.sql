-- ============================================================
-- ARRIENDOS CARTAGENA · Datos iniciales
-- ------------------------------------------------------------
-- Crea el usuario para iniciar sesión y los 7 apartamentos.
-- Edita nombres/precios como necesites antes o después de correr esto.
-- ============================================================

-- Usuario para entrar a la aplicación (CAMBIA la contraseña luego de
-- iniciar sesión con "Cambiar contraseña"; esta es solo para arrancar).
INSERT INTO usuarios (nombre, email, password_hash) VALUES
    ('Propietario', 'papa@arriendoscartagena.com', crypt('cambiame123', gen_salt('bf', 10)));

-- Los 7 apartamentos. Ajusta nombre/descripcion/capacidad/precio a los reales;
-- el campo ical_url_importar se deja vacío y se completa desde la app
-- (pantalla "Apartamentos") pegando el link que da Booking/Airbnb.
INSERT INTO apartamentos (nombre, descripcion, capacidad, precio_noche_base) VALUES
    ('Apto 1 - Bocagrande',   'Apartamento 1', 2, 250000),
    ('Apto 2 - Bocagrande',   'Apartamento 2', 2, 250000),
    ('Apto 3 - Bocagrande',   'Apartamento 3', 4, 320000),
    ('Apto 4 - Centro',       'Apartamento 4', 2, 220000),
    ('Apto 5 - Centro',       'Apartamento 5', 4, 300000),
    ('Apto 6 - Castillogrande','Apartamento 6', 6, 420000),
    ('Apto 7 - Castillogrande','Apartamento 7', 3, 280000);

-- Las 5 niñas de limpieza iniciales. Edita nombre/teléfono desde la app
-- (pestaña "Limpieza") cuando tengas los datos reales.
INSERT INTO personal_limpieza (nombre, telefono) VALUES
    ('María',     '3000000001'),
    ('Carmen',    '3000000002'),
    ('Luz Dary',  '3000000003'),
    ('Yolanda',   '3000000004'),
    ('Esperanza', '3000000005');

-- Productos iniciales de la lavandería. Ajusta cantidad/valor desde la app
-- (pestaña "Productos" dentro de Lavandería) cuando tengas los datos reales.
INSERT INTO productos_lavanderia (nombre, cantidad, unidad, valor_unitario) VALUES
    ('Jabón en polvo', 10, 'kg',     8000),
    ('Desmanchante',    5, 'litros', 12000),
    ('Vinagre',         8, 'litros', 4000),
    ('Suavizante',      6, 'litros', 9000);
