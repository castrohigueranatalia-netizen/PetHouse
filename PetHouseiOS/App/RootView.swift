//
//  RootView.swift
//  App
//
//  Único punto de bifurcación entre "sesión iniciada" (TabView de la app) y "sin sesión"
//  (flujo de auth). El onboarding es corto a propósito: login/registro sin fricción, y de
//  ahí directo a Buscar (ver system prompt del MVP — "ir directo a buscar tras login").
//

import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.estado {
            case .verificando:
                VStack(spacing: PHSpacing.s24) {
                    PHLogo(height: 72)
                    PHLoadingStateView(mensaje: "Verificando tu sesión…")
                        .frame(maxHeight: 120)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PHColor.canvas)
            case .invitado:
                AuthFlowView()
            case .autenticado:
                MainTabView()
            }
        }
        .animation(.default, value: session.estado)
    }
}

/// Contenedor de login/registro. Sin `TabView`, es un flujo lineal simple.
private struct AuthFlowView: View {
    var body: some View {
        NavigationStack {
            LoginView()
        }
    }
}

private enum Pestana: Hashable {
    case buscar, reservas, mensajes, perfil
}

struct MainTabView: View {
    @Environment(SessionStore.self) private var session
    @State private var pestanaSeleccionada: Pestana = .buscar

    // SOLO 4 pestañas, siempre — a propósito, nunca condicionadas a rol. Con más de 5
    // pestañas, iOS deja de mostrarlas todas y agrupa el resto adentro de una pestaña "Más"
    // que él mismo genera — y una vez ahí, las ventanitas (`.sheet`) que abre esa pantalla no
    // se presentan de forma confiable (bug conocido de SwiftUI/UIKit). Eso fue lo que dejó sin
    // funcionar "editar perfil"/"editar mascota" apenas la cuenta pasó a tener también la
    // pestaña Anfitrión: Buscar+Favoritos+Reservas+Mensajes+Anfitrión+Perfil = 6, y las dos
    // últimas quedaban escondidas en el "Más" de iOS. Por eso Favoritos, Anfitrión y el panel
    // de Admin ahora se abren desde adentro de Perfil (ver `seccionCuenta`) en vez de ser
    // pestañas propias — así el total nunca puede superar 4, sin importar la combinación de
    // roles que tenga la cuenta.
    var body: some View {
        TabView(selection: $pestanaSeleccionada) {
            NavigationStack {
                BuscarView()
            }
            .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
            .tag(Pestana.buscar)

            NavigationStack {
                MisReservasView()
            }
            .tabItem { Label("Reservas", systemImage: "calendar") }
            .tag(Pestana.reservas)

            NavigationStack {
                ConversacionesView()
            }
            .tabItem { Label("Mensajes", systemImage: "message") }
            .badge(session.mensajesNoLeidos)
            .tag(Pestana.mensajes)

            NavigationStack {
                PerfilView()
            }
            .tabItem { Label("Perfil", systemImage: "person.circle") }
            .tag(Pestana.perfil)
        }
        .tint(PHColor.primary)
        // Justo después de un registro con "También quiero ofrecer hospedaje" marcado
        // (ver SessionStore.abrirVerificacionAlEntrar): salta a la pestaña Perfil, que a su
        // vez empuja VerificacionAnfitrionView al ver la misma señal en `true`.
        .task { if session.abrirVerificacionAlEntrar { pestanaSeleccionada = .perfil } }
        .onChange(of: session.abrirVerificacionAlEntrar) { _, abrir in
            if abrir { pestanaSeleccionada = .perfil }
        }
        // El logo en cada pestaña funciona como botón de inicio (ver SessionStore.
        // volverABuscar): salta a la pestaña Buscar. BuscarView, además, reacciona a la
        // misma señal para cerrar cualquier hospedaje que hubiera quedado abierto en su
        // propio stack — ver el comentario largo en AppState.swift.
        .onChange(of: session.volverABuscar) { _, volver in
            if volver { pestanaSeleccionada = .buscar }
        }
        // Aviso de "tu solicitud de anfitrión/reserva se resolvió" o "te llegó una
        // solicitud nueva" (ver SessionStore.revisarResolucionVerificacion/
        // revisarResolucionesReserva/revisarSolicitudesNuevasAnfitrion, sin push
        // notifications — ADR-7): se revisa al arrancar la sesión/loguearse/registrarse, y
        // se muestra ACÁ, en la raíz de las pestañas, para que sea lo primero que se ve al
        // entrar a la app — no algo que depende de que el usuario llegue a abrir el Perfil o
        // Mis reservas.
        //
        // UN SOLO `.alert` para LOS TRES avisos (no modificadores separados): dos `.alert`
        // con `isPresented` en `true` a la vez es un estado no soportado por SwiftUI (el
        // segundo puede no aparecer o pisar al primero) — acá se decide adentro cuál
        // mostrar, con esta prioridad: verificación de anfitrión, después reservas propias
        // resueltas, después solicitudes nuevas recibidas. Si hay varios avisos en cola (de
        // cualquiera de los tres tipos), se muestran de a uno: al tocar "Entendido" se apaga
        // el de arriba y, si queda otro pendiente, el mismo `.alert` se vuelve a presentar.
        //
        // El `set` del binding TIENE que apagar el aviso de verdad, no descartar el valor.
        // SwiftUI escribe `false` acá apenas el aviso se cierra; si ese valor se ignora, el
        // getter sigue respondiendo `true` y SwiftUI queda creyendo que todavía hay un aviso
        // montado sobre estas pestañas. En ese estado inconsistente, las ventanitas
        // (`.sheet`) que abren las pantallas de adentro —editar perfil, agregar/editar
        // mascota— dejan de presentarse EN SILENCIO: el botón responde, cambia el estado, y
        // no pasa nada. Eso era exactamente el síntoma que se estaba viendo en Perfil.
        .alert(
            tituloAviso,
            isPresented: Binding(
                get: { hayAvisoPendiente },
                set: { sigueVisible in
                    if !sigueVisible { Task { await confirmarAvisoPendiente() } }
                }
            ),
            actions: {
                // Solo la solicitud nueva tiene una segunda acción — lleva derecho a la
                // reserva en la pestaña Reservas. La condición repite a mano la misma
                // prioridad que `tituloAviso`/`mensajeAviso` (verificación > reserva
                // resuelta > solicitud nueva), para mostrar el botón solo cuando la
                // solicitud nueva es de verdad el aviso que se está mostrando ahora mismo.
                // Se lee `.first` ACÁ, antes de que el `set` de arriba la saque de la cola.
                if session.resolucionVerificacion == nil, session.resolucionesReserva.isEmpty,
                   let solicitud = session.solicitudesNuevasAnfitrion.first {
                    Button("Ver reserva") {
                        session.reservaRecibidaParaAbrir = solicitud
                        pestanaSeleccionada = .reservas
                    }
                }
                // Sin trabajo propio a propósito: cerrar el aviso ya dispara el `set` de
                // arriba, que es el único lugar donde se apaga (una sola fuente de verdad).
                Button("Entendido") {}
            },
            message: { Text(mensajeAviso) }
        )
    }

    private var hayAvisoPendiente: Bool {
        session.resolucionVerificacion != nil
            || !session.resolucionesReserva.isEmpty
            || !session.solicitudesNuevasAnfitrion.isEmpty
    }

    private func confirmarAvisoPendiente() async {
        if session.resolucionVerificacion != nil {
            await session.marcarResolucionVista()
        } else if !session.resolucionesReserva.isEmpty {
            await session.marcarResolucionReservaVista()
        } else {
            await session.marcarSolicitudNuevaAnfitrionVista()
        }
    }

    private var tituloAviso: String {
        if session.resolucionVerificacion != nil {
            return session.resolucionVerificacion?.estado == .aprobado ? "¡Solicitud aprobada!" : "Solicitud rechazada"
        }
        if let reserva = session.resolucionesReserva.first {
            return reserva.estado == .confirmada ? "¡Reserva confirmada!" : "Solicitud de reserva rechazada"
        }
        if session.solicitudesNuevasAnfitrion.first != nil {
            return "¡Nueva solicitud de reserva!"
        }
        return ""
    }

    private var mensajeAviso: String {
        if session.resolucionVerificacion != nil {
            return session.resolucionVerificacion?.estado == .aprobado
                ? "Ya eres anfitrión en PetHouse. Publica tu primer hospedaje desde Perfil › Mis hospedajes."
                : "Tu solicitud de anfitrión no fue aprobada esta vez. Puedes volver a intentarlo desde tu perfil."
        }
        if let reserva = session.resolucionesReserva.first {
            let lugar = reserva.hospedajeTitulo ?? "el hospedaje"
            return reserva.estado == .confirmada
                ? "El anfitrión aceptó tu solicitud en \(lugar). Revisa los detalles en la pestaña Reservas."
                : "El anfitrión no pudo aceptar tu solicitud en \(lugar). Puedes buscar otro hospedaje disponible."
        }
        if let solicitud = session.solicitudesNuevasAnfitrion.first {
            let quien = solicitud.usuarioNombre ?? "Un huésped"
            let lugar = solicitud.hospedajeTitulo ?? "tu hospedaje"
            return "\(quien) quiere reservar en \(lugar). Revisa la solicitud para aceptarla o rechazarla."
        }
        return ""
    }
}
