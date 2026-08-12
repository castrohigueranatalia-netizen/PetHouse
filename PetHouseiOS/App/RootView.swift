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
    case buscar, favoritos, reservas, mensajes, anfitrion, admin, perfil
}

struct MainTabView: View {
    @Environment(SessionStore.self) private var session
    @State private var pestanaSeleccionada: Pestana = .buscar

    var body: some View {
        TabView(selection: $pestanaSeleccionada) {
            NavigationStack {
                BuscarView()
            }
            .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
            .tag(Pestana.buscar)

            NavigationStack {
                FavoritosView()
            }
            .tabItem { Label("Favoritos", systemImage: "heart") }
            .tag(Pestana.favoritos)

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

            if session.usuario?.esAnfitrion == true {
                NavigationStack {
                    MisHospedajesView()
                }
                .tabItem { Label("Anfitrión", systemImage: "building.2.fill") }
                .tag(Pestana.anfitrion)
            }

            if session.usuario?.rol == .admin {
                NavigationStack {
                    AdminView()
                }
                .tabItem { Label("Admin", systemImage: "shield.fill") }
                .badge(session.solicitudesPendientes)
                .tag(Pestana.admin)
            }

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
    }
}
