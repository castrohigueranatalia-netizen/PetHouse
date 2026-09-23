-- Uso único: carga el borrador de política de privacidad y términos de uso (el que
-- redactamos juntos) en documentos_legales, para que el panel de admin y la app ya
-- muestren contenido real en vez de estar vacíos. Sigue siendo un BORRADOR — quedan
-- [corchetes] por llenar (nombre legal, correo, fecha, política de cancelación) y falta
-- que un abogado revise la sección de responsabilidad antes de publicar de verdad. Se
-- puede seguir editando desde el panel (Entidad legal) en cualquier momento.

UPDATE documentos_legales SET actualizado_en = now(), contenido = $doc$En PetHouse conectamos a personas que necesitan un lugar de confianza para dejar a su mascota con anfitriones verificados que ofrecen ese espacio en su hogar, en Bogotá. Para que eso funcione necesitamos algunos datos tuyos y de tu mascota — esta política explica cuáles, para qué los usamos, y qué puedes hacer en cualquier momento para consultarlos, corregirlos o pedir que los borremos.

1. ¿Quién es el responsable de tus datos?

[Nombre legal de PetHouse / persona natural o jurídica], con domicilio en Bogotá, Colombia, correo de contacto [correo], es responsable del tratamiento de los datos personales que recogemos a través de la aplicación PetHouse.

2. ¿Qué datos recogemos?

- Nombre, correo, teléfono (todo usuario) — crear tu cuenta, identificarte, contactarte sobre tus reservas.
- Foto de perfil (opcional) — que anfitriones/huéspedes sepan con quién están hablando.
- Nombre, especie, raza, edad, tamaño, fotos, vacunas, medicamentos y notas de tu mascota (dueños de mascota) — que el anfitrión sepa a quién va a cuidar y pueda decidir si acepta la reserva.
- Ubicación de tu hospedaje, barrio y coordenadas aproximadas (anfitriones) — que los huéspedes puedan buscar por cercanía.
- Nombre legal completo, número de cédula, certificado de antecedentes, fotos tuyas y de tu vivienda (solo quienes quieren ser anfitriones) — verificar tu identidad antes de dejarte publicar un hospedaje.
- Certificado de un curso de primeros auxilios para mascotas (solo anfitriones) — confirmar que sabes qué hacer ante una urgencia mientras cuidas una mascota ajena.
- Grabación o notas de la videollamada (o visita) de verificación del hogar (solo anfitriones) — confirmar que el espacio que muestran las fotos es real y apto.
- Mensajes que envías por el chat de la app (todo usuario) — que anfitrión y huésped coordinen la estadía.
- Fechas, mascotas y precio de cada reserva (todo usuario) — procesar la reserva y mantener tu historial.
- Calificaciones y reseñas que escribes o recibes (todo usuario) — que la comunidad pueda confiar en quién reserva o en quién aloja.
- Identificador de tu dispositivo, si activas notificaciones (opcional) — avisarte cuando algo pasa con tus reservas.

Lo que NO recogemos: número de tarjeta, CVV, ni ningún dato bancario — hoy el pago se coordina directamente entre anfitrión y huésped fuera de la app; PetHouse no procesa pagos ni los guarda.

3. Datos sensibles: cédula y antecedentes

Si decides convertirte en anfitrión, te pedimos tu número de cédula y un certificado de antecedentes policiales. La ley colombiana considera esto un dato sensible, así que:
- Te lo pedimos con una autorización aparte y explícita (no basta con aceptar esta política en general).
- No estás obligado a dártelo — pero sin él no puedes publicar un hospedaje, porque es la forma en que verificamos que quien va a cuidar mascotas ajenas es quien dice ser.
- Ese dato viaja y se guarda protegido con controles de acceso específicos, y solo lo puede ver el equipo de PetHouse encargado de aprobar solicitudes de anfitrión — nunca se muestra a otros usuarios de la app.

4. ¿Con quién compartimos tus datos?

- Con otro usuario, solo lo necesario para una reserva: si reservas con un anfitrión, él ve tu nombre, foto y los datos de tu mascota que agregaste a esa reserva — no tu cédula, ni tu correo completo si no lo compartes por chat.
- No vendemos tus datos a nadie. No compartimos tu información con terceros para fines publicitarios.
- Por obligación legal: si una autoridad colombiana nos lo exige por ley, podemos tener que entregar datos puntuales.

5. ¿Cuánto tiempo guardamos tus datos?

Mientras tengas una cuenta activa. Si la eliminas, borramos tus datos personales dentro de [plazo, ej. 30 días], salvo la información que estemos obligados a conservar por ley o la necesaria para resolver una disputa ya abierta.

6. Tus derechos

Como titular de tus datos, en cualquier momento puedes:
- Conocer, actualizar y rectificar tus datos (desde tu Perfil en la app, o escribiéndonos).
- Pedir prueba de la autorización que nos diste.
- Ser informado sobre el uso que le hemos dado a tus datos.
- Revocar tu autorización y/o pedir que eliminemos tus datos, cuando la ley lo permita.
- Acceder gratuitamente a tus datos personales.
- Presentar una queja ante la Superintendencia de Industria y Comercio (SIC) si consideras que no estamos cumpliendo la ley.

Para ejercer cualquiera de estos derechos, escríbenos a [correo de contacto]. Vamos a responder dentro de los plazos que establece la ley (10 días hábiles para consultas, 15 días hábiles para reclamos).

7. Seguridad

Guardamos tus datos con controles técnicos razonables para su volumen y sensibilidad — tus fotos y documentos de verificación, por ejemplo, solo son accesibles con enlaces protegidos y de corta duración, nunca de forma pública. Ningún sistema es 100% infalible, pero trabajamos activamente para minimizar riesgos.

8. Menores de edad

PetHouse está pensado para mayores de 18 años. No recogemos intencionalmente datos de menores de edad.

9. Cambios a esta política

Si cambiamos esta política de forma importante, te avisamos dentro de la app antes de que el cambio entre en vigencia.

10. Contacto

¿Preguntas sobre tus datos? Escríbenos a [correo de contacto].$doc$
WHERE tipo = 'privacidad';

UPDATE documentos_legales SET actualizado_en = now(), contenido = $doc$Al crear una cuenta o usar PetHouse, aceptas estos términos. Léelos con calma — resumimos lo importante en lenguaje simple, pero también es un documento legal.

1. Qué es PetHouse (y qué no es)

PetHouse es una plataforma de intermediación: conectamos a dueños de mascotas ("Huéspedes") con personas que ofrecen su hogar para cuidarlas ("Anfitriones"), en Bogotá. Nosotros:
- Verificamos la identidad de cada anfitrión antes de dejarlo publicar (cédula, antecedentes, fotos de su vivienda).
- Facilitamos la búsqueda, la reserva y la comunicación entre las partes.

Nosotros NO somos:
- Una empresa de cuidado de mascotas — el servicio real de cuidado lo presta el Anfitrión, no PetHouse.
- Una pasarela de pagos — hoy el pago se coordina directamente entre Huésped y Anfitrión, fuera de la app. PetHouse no procesa, retiene ni garantiza ningún pago.
- Un garante de que nada saldrá mal — verificar la identidad de un anfitrión reduce el riesgo, pero no es una garantía absoluta de seguridad; usa tu criterio, revisa el perfil, las reseñas, y comunícate por el chat antes de reservar.

2. Quién puede usar PetHouse

Debes ser mayor de 18 años y dar información veraz al registrarte. Eres responsable de mantener tu contraseña segura y de todo lo que pase en tu cuenta.

3. Ser Anfitrión

Para publicar un hospedaje debes completar la verificación de seguridad, que incluye:
- Tu nombre legal, cédula, certificado de antecedentes y referencias.
- Fotos tuyas y de tu vivienda.
- Un certificado vigente de un curso de primeros auxilios para mascotas — queremos que sepas qué hacer ante una urgencia mientras cuidas una mascota ajena. Aceptamos el curso gratuito y certificado de la Red Doméstica (Red Internacional de Ciudades por la Protección Animal Doméstica, 40 horas, virtual), o uno equivalente de otra institución reconocida.
- Una videollamada (o, cuando sea posible, una visita) de verificación del hogar — para confirmar que el espacio donde vas a alojar mascotas es real y apto, más allá de lo que muestran las fotos.

PetHouse revisa toda esta información y decide si aprueba tu solicitud — podemos rechazarla o pedirte que la corrijas, y podemos revocar tu condición de anfitrión en cualquier momento si detectamos información falsa o un comportamiento que ponga en riesgo a otros usuarios, a sus mascotas, o a ti mismo.

4. Reservar y cancelar

- Una reserva queda pendiente hasta que el anfitrión la acepta.
- El anfitrión puede rechazar una solicitud sin tener que dar una razón.
- [Política de cancelación por definir: cuántos días antes se puede cancelar sin costo, y si hay reembolso.]
- Como el pago se coordina fuera de la app, cualquier reembolso también se coordina directamente entre Huésped y Anfitrión — PetHouse puede mediar si hay una disputa, pero no procesa el reembolso.

5. Tu comportamiento en la plataforma

No está permitido:
- Dar información falsa (sobre ti, tu mascota o tu vivienda).
- Usar la app para algo distinto a coordinar el cuidado de una mascota.
- Contactar a otro usuario fuera de la app para saltarte el proceso de verificación/reserva.
- Acosar, discriminar o maltratar a otro usuario.

Podemos suspender o cerrar cuentas que incumplan esto.

6. Calificaciones y reseñas

Después de una estadía, Huésped y Anfitrión pueden calificarse mutuamente. Las reseñas deben ser honestas y basadas en tu experiencia real — no se permiten reseñas falsas, ni a cambio de compensación.

7. Propiedad de tu contenido

Las fotos y descripciones que subes siguen siendo tuyas. Al publicarlas en PetHouse, nos das permiso para mostrarlas dentro de la app (por ejemplo, la foto de tu mascota en el detalle de una reserva) — nada más.

8. Responsabilidad durante el cuidado de la mascota

PetHouse verifica anfitriones e impone requisitos pensados para reducir el riesgo (documentos, curso de primeros auxilios, videollamada/visita del hogar), pero no está presente durante el cuidado real de la mascota y no puede controlar lo que pase en ese tiempo. Por eso:

8.1 — Como Huésped, reconoces que:
- Eres el dueño (o tenedor legal) de tu mascota y sigues siendo responsable por su comportamiento y sus necesidades, incluyendo cualquier daño que cause a personas, otras mascotas o bienes mientras está en cuidado de un Anfitrión.
- Debes informar con veracidad al Anfitrión sobre el temperamento, la salud, las alergias y cualquier condición especial de tu mascota antes de que la reciba.
- Autorizas al Anfitrión, mientras dure la estadía, a tomar decisiones razonables de cuidado inmediato (incluyendo llevarla a atención veterinaria de urgencia) si no logra contactarte a tiempo.

8.2 — Como Anfitrión, reconoces que:
- Cuidar una mascota ajena implica riesgos inherentes (mordidas, arañazos, daños a tu hogar, contagios entre mascotas) que aceptas al ofrecerte como Anfitrión.
- Te comprometes a brindar un cuidado razonable y diligente, y a avisar de inmediato al Huésped (y a buscar atención veterinaria) ante cualquier accidente, enfermedad o emergencia con la mascota a tu cargo.
- Eres responsable de que tu hogar, tu propia familia y tus propias mascotas (si tienes) sean un entorno seguro para alojar una mascota ajena.

8.3 — El daño que cause una mascota a un tercero (otro huésped, un vecino, alguien en la calle) mientras está bajo el cuidado del Anfitrión se rige por las reglas generales de responsabilidad civil por animales del Código Civil colombiano — en la práctica, esto puede recaer sobre el Huésped (dueño), sobre el Anfitrión (tenedor al momento del hecho), o sobre ambos, según las circunstancias. Huésped y Anfitrión son responsables entre sí y frente a terceros por los daños que les sean atribuibles — PetHouse no asume esa responsabilidad en su lugar.

8.4 — PetHouse no es parte de la relación de cuidado entre Huésped y Anfitrión y no responde por lo que ocurra durante la estadía, salvo que el daño sea consecuencia directa de un incumplimiento de PetHouse a sus propias obligaciones (por ejemplo, no realizar la verificación que promete en la sección 3). Huésped y Anfitrión acuerdan mantener indemne a PetHouse frente a reclamos de uno contra el otro derivados del cuidado de la mascota.

8.5 — Tampoco garantizamos que la plataforma esté libre de errores el 100% del tiempo.

9. Cambios y terminación

Podemos actualizar estos términos — te avisamos dentro de la app antes de que el cambio entre en vigencia. Puedes cerrar tu cuenta cuando quieras desde Perfil.

10. Ley aplicable

Estos términos se rigen por las leyes de la República de Colombia. Cualquier disputa se resuelve ante los jueces competentes de Bogotá [o mediante un mecanismo de resolución alternativa que se defina más adelante].

11. Contacto

[correo de contacto]$doc$
WHERE tipo = 'terminos';
