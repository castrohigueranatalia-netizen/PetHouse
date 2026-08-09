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
                PHLoadingStateView(mensaje: "Verificando tu sesión…")
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

struct MainTabView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        TabView {
            NavigationStack {
                BuscarView()
            }
            .tabItem { Label("Buscar", systemImage: "magnifyingglass") }

            NavigationStack {
                FavoritosView()
            }
            .tabItem { Label("Favoritos", systemImage: "heart") }

            NavigationStack {
                MisReservasView()
            }
            .tabItem { Label("Reservas", systemImage: "calendar") }

            NavigationStack {
                ConversacionesView()
            }
            .tabItem { Label("Mensajes", systemImage: "message") }

            if session.usuario?.rol == .anfitrion {
                NavigationStack {
                    MisHospedajesView()
                }
                .tabItem { Label("Anfitrión", systemImage: "building.2.fill") }
            }

            NavigationStack {
                PerfilView()
            }
            .tabItem { Label("Perfil", systemImage: "person.circle") }
        }
        .tint(PHColor.primary)
    }
}
