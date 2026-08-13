//
//  PerfilView.swift
//  Features/Perfil
//

import SwiftUI

struct PerfilView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel: PerfilViewModel?
    @State private var mostrarEditar = false
    @State private var mostrarAgregarMascota = false
    @State private var mascotaParaEditar: Mascota?
    @State private var mostrarConfirmacionLogout = false

    var body: some View {
        ScrollView {
            if let usuario = session.usuario {
                VStack(alignment: .leading, spacing: PHSpacing.s24) {
                    encabezado(usuario)

                    if session.perfilEsDeCache {
                        PHBadge("Datos guardados sin conexión", style: .warning)
                    }

                    seccionMascotas

                    seccionCuenta

                    PHTextButton("Cerrar sesión", role: .destructive) {
                        mostrarConfirmacionLogout = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, PHSpacing.s16)
                }
                .padding(PHSpacing.s16)
            } else {
                PHLoadingStateView()
            }
        }
        .background(PHColor.canvas)
        .navigationTitle("Perfil")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { session.volverABuscar = true } label: {
                    PHLogo(height: 28)
                }
                .accessibilityLabel("Ir al listado de hospedajes")
            }
        }
        .refreshable { await viewModel?.refrescar() }
        .onAppear {
            if viewModel == nil { viewModel = PerfilViewModel(session: session) }
        }
        .sheet(isPresented: $mostrarEditar) { EditarPerfilView() }
        .sheet(isPresented: $mostrarAgregarMascota) { MascotaFormView(mascota: nil) }
        .sheet(item: $mascotaParaEditar) { mascota in MascotaFormView(mascota: mascota) }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $mostrarConfirmacionLogout, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                Task { await session.cerrarSesion() }
            }
            Button("Cancelar", role: .cancel) {}
        }
        // Consume la señal de "También quiero ofrecer hospedaje" marcada en el registro
        // (ver SessionStore.abrirVerificacionAlEntrar y MainTabView, que ya saltó a esta
        // pestaña) empujando la verificación automáticamente. `isPresented` limpia la
        // señal sola al volver (se pone en `false` cuando el usuario cierra/completa).
        .navigationDestination(isPresented: Binding(
            get: { session.abrirVerificacionAlEntrar },
            set: { session.abrirVerificacionAlEntrar = $0 }
        )) {
            VerificacionAnfitrionView()
        }
        // El aviso de "tu solicitud se resolvió" se muestra desde MainTabView (aparece
        // apenas se entra a la app, en cualquier pestaña) — ver App/RootView.swift.
    }

    private func encabezado(_ usuario: Usuario) -> some View {
        HStack(spacing: PHSpacing.s16) {
            PHAvatar(name: usuario.nombre, urlString: MediaURL.resolver(usuario.fotoUrl), size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(usuario.nombre)
                    .phText(PHFont.displaySM, color: PHColor.ink)
                Text(usuario.email)
                    .phText(PHFont.bodySM, color: PHColor.muted)
                HStack(spacing: PHSpacing.s8) {
                    // Dueño de mascota y anfitrión ya no son excluyentes — una cuenta
                    // puede tener ambas insignias a la vez (ver Usuario.esAnfitrion).
                    PHBadge("Dueño de mascota")
                    if usuario.esAnfitrion {
                        PHBadge("Anfitrión")
                    }
                    if usuario.verificado {
                        PHBadge("Verificado", style: .success)
                    }
                }
            }
            Spacer()
            PHIconButton(systemImage: "pencil", accessibilityLabel: "Editar perfil") {
                mostrarEditar = true
            }
        }
    }

    private var seccionMascotas: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            HStack {
                Text("Mis mascotas")
                    .phText(PHFont.titleMD, color: PHColor.ink)
                Spacer()
                PHIconButton(systemImage: "plus", accessibilityLabel: "Agregar mascota") {
                    mostrarAgregarMascota = true
                }
            }

            if session.mascotas.isEmpty {
                PHEmptyStateView(
                    systemImage: "pawprint",
                    titulo: "Sin mascotas registradas",
                    mensaje: "Agrega a tu mascota para poder reservar hospedajes.",
                    accionTitulo: "Agregar mascota"
                ) {
                    mostrarAgregarMascota = true
                }
                .frame(height: 220)
            } else {
                VStack(spacing: PHSpacing.s8) {
                    ForEach(session.mascotas) { mascota in
                        PHMascotaCard(
                            mascota,
                            onEditar: { mascotaParaEditar = mascota },
                            onEliminar: { Task { await viewModel?.eliminarMascota(mascota) } }
                        )
                    }
                }
                if let error = viewModel?.errorEliminarMascota {
                    Text(error.localizedDescription)
                        .phText(PHFont.captionSM, color: error.esFuncionPendiente ? PHColor.warning : PHColor.error)
                }
            }
        }
    }

    private var seccionCuenta: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text("Cuenta")
                .phText(PHFont.titleMD, color: PHColor.ink)
            NavigationLink {
                FavoritosView()
            } label: {
                filaCuenta("Favoritos", icono: "heart")
            }

            if session.usuario?.esAnfitrion == false {
                conviertete
            }
        }
    }

    /// Aditivo: activar la capacidad de anfitrión requiere pasar por la verificación de
    /// seguridad primero (ver VerificacionAnfitrionView) — no hay atajo directo. La MISMA
    /// cuenta gana la capacidad, no se crea otra ni se cierra la sesión actual.
    private var conviertete: some View {
        NavigationLink {
            VerificacionAnfitrionView()
        } label: {
            HStack {
                Image(systemName: "house.and.flag").foregroundStyle(PHColor.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conviértete en anfitrión")
                        .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                    Text("Publica un espacio y empieza a hospedar mascotas, sin dejar de poder reservar.")
                        .phText(PHFont.captionSM, color: PHColor.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(PHColor.mutedSoft).font(.caption)
            }
            .padding(PHSpacing.s12)
            .background(PHColor.primaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func filaCuenta(_ titulo: String, icono: String) -> some View {
        HStack {
            Image(systemName: icono).foregroundStyle(PHColor.primary)
            Text(titulo).phText(PHFont.bodyMD, color: PHColor.ink)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(PHColor.mutedSoft).font(.caption)
        }
        .padding(PHSpacing.s12)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }
}
