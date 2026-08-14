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
        // Aviso de "tu solicitud de anfitrión/reserva se resolvió" (ver SessionStore.
        // revisarResolucionVerificacion/revisarResolucionesReserva, sin push notifications —
        // ADR-7): se revisa al arrancar la sesión/loguearse/registrarse, y se muestra ACÁ, en
        // la raíz de las pestañas, para que sea lo primero que se ve al entrar a la app — no
        // algo que depende de que el usuario llegue a abrir el Perfil o Mis reservas.
        //
        // UN SOLO `.alert` para ambos avisos (no dos modificadores separados): dos `.alert`
        // con `isPresented` en `true` a la vez es un estado no soportado por SwiftUI (el
        // segundo puede no aparecer o pisar al primero) — acá se decide adentro cuál mostrar,
        // dando prioridad a la verificación de anfitrión si ambos están pendientes. Si hay
        // varias reservas resueltas sin ver, se muestran de a una: al tocar "Entendido" se
        // apaga la primera y, si `resolucionesReserva` sigue sin estar vacío, el mismo
        // `.alert` se vuelve a presentar con la siguiente.
        .alert(
            tituloAviso,
            isPresented: Binding(get: { hayAvisoPendiente }, set: { _ in }),
            actions: {
                Button("Entendido") { Task { await confirmarAvisoPendiente() } }
            },
            message: { Text(mensajeAviso) }
        )
    }

    private var hayAvisoPendiente: Bool {
        session.resolucionVerificacion != nil || !session.resolucionesReserva.isEmpty
    }

    private func confirmarAvisoPendiente() async {
        if session.resolucionVerificacion != nil {
            await session.marcarResolucionVista()
        } else {
            await session.marcarResolucionReservaVista()
        }
    }

    private var tituloAviso: String {
        if session.resolucionVerificacion != nil {
            return session.resolucionVerificacion?.estado == .aprobado ? "¡Solicitud aprobada!" : "Solicitud rechazada"
        }
        if let reserva = session.resolucionesReserva.first {
            return reserva.estado == .confirmada ? "¡Reserva confirmada!" : "Solicitud de reserva rechazada"
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
        return ""
    }
}
