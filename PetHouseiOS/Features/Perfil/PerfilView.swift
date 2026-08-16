//
//  PerfilView.swift
//  Features/Perfil
//

import SwiftUI

/// Los distintos sheets que puede abrir esta pantalla, unificados en un solo enum. Encadenar
/// varios `.sheet(...)` separados sobre la misma vista es poco confiable en SwiftUI (a veces
/// deja de responder alguno de ellos sin avisar) — con un solo `.sheet(item:)` que despacha
/// según el caso, solo hay UNA presentación activa a la vez y no hay conflicto posible.
private enum SheetPerfil: Identifiable {
    case editarPerfil
    case agregarMascota
    case editarMascota(Mascota)
    case verFicha(Mascota)

    var id: String {
        switch self {
        case .editarPerfil: "editarPerfil"
        case .agregarMascota: "agregarMascota"
        case .editarMascota(let mascota): "editarMascota-\(mascota.id)"
        case .verFicha(let mascota): "verFicha-\(mascota.id)"
        }
    }
}

struct PerfilView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel: PerfilViewModel?
    @State private var sheetActivo: SheetPerfil?
    /// Puente entre "ver ficha" y "editar mascota": tocar "Editar" dentro de la ficha guarda
    /// acá cuál mascota editar y cierra el sheet actual (`sheetActivo = nil`); recién en
    /// `onDismiss` (cuando ese cierre YA terminó) se abre el sheet de edición — presentar un
    /// sheet nuevo mientras el anterior todavía se está cerrando puede fallar en silencio.
    @State private var mascotaPendienteParaEditar: Mascota?
    @State private var mostrarConfirmacionLogout = false
    @State private var mostrarVerificacion = false
    @State private var fotoVisor: FotoVisorItem?

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
        .sheet(
            item: $sheetActivo,
            onDismiss: {
                if let pendiente = mascotaPendienteParaEditar {
                    mascotaPendienteParaEditar = nil
                    sheetActivo = .editarMascota(pendiente)
                }
            }
        ) { sheet in
            switch sheet {
            case .editarPerfil:
                EditarPerfilView(session: session)
            case .agregarMascota:
                MascotaFormView(mascota: nil, session: session)
            case .editarMascota(let mascota):
                MascotaFormView(mascota: mascota, session: session)
            case .verFicha(let mascota):
                FichaMascotaView(mascota: mascota, onEditar: {
                    mascotaPendienteParaEditar = mascota
                    sheetActivo = nil
                })
            }
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $mostrarConfirmacionLogout, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                Task { await session.cerrarSesion() }
            }
            Button("Cancelar", role: .cancel) {}
        }
        // UN SOLO `.navigationDestination` para las DOS formas de entrar a la verificación de
        // anfitrión, no dos modificadores separados: (1) el botón "Conviértete en anfitrión"
        // de acá abajo, y (2) la señal "También quiero ofrecer hospedaje" marcada en el
        // registro (ver SessionStore.abrirVerificacionAlEntrar y MainTabView, que ya saltó a
        // esta pestaña). Dos `.navigationDestination(isPresented:)` sobre la MISMA vista es
        // comportamiento indefinido en SwiftUI — se pisan entre ellos y enredan el sistema de
        // presentación de toda la pantalla, que es lo que dejaba sin abrir las ventanitas de
        // editar perfil / agregar mascota. Como ambas entradas empujan exactamente la misma
        // pantalla, se unifican en un destino único: se abre si CUALQUIERA de las dos señales
        // está encendida, y al cerrarse se apagan las dos.
        .navigationDestination(isPresented: Binding(
            get: { mostrarVerificacion || session.abrirVerificacionAlEntrar },
            set: { abierto in
                if !abierto { cerrarVerificacion() }
            }
        )) {
            VerificacionAnfitrionView { cerrarVerificacion() }
        }
        // El aviso de "tu solicitud se resolvió" se muestra desde MainTabView (aparece
        // apenas se entra a la app, en cualquier pestaña) — ver App/RootView.swift.
        .fullScreenCover(item: $fotoVisor) { item in
            PHVisorFotos(urls: item.urls, indiceInicial: item.indiceInicial)
        }
    }

    /// Apaga las dos señales que pueden abrir la verificación de anfitrión — ver el
    /// `.navigationDestination` unificado de arriba.
    private func cerrarVerificacion() {
        mostrarVerificacion = false
        session.abrirVerificacionAlEntrar = false
    }

    private func encabezado(_ usuario: Usuario) -> some View {
        HStack(spacing: PHSpacing.s16) {
            Button {
                if let foto = usuario.fotoUrl { fotoVisor = FotoVisorItem(urls: [foto]) }
            } label: {
                PHAvatar(name: usuario.nombre, urlString: MediaURL.resolver(usuario.fotoUrl), size: 64)
            }
            .buttonStyle(.plain)
            .disabled(usuario.fotoUrl == nil)
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
                sheetActivo = .editarPerfil
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
                    sheetActivo = .agregarMascota
                }
            }

            if session.mascotas.isEmpty {
                PHEmptyStateView(
                    systemImage: "pawprint",
                    titulo: "Sin mascotas registradas",
                    mensaje: "Agrega a tu mascota para poder reservar hospedajes.",
                    accionTitulo: "Agregar mascota"
                ) {
                    sheetActivo = .agregarMascota
                }
                .frame(height: 220)
            } else {
                VStack(spacing: PHSpacing.s8) {
                    ForEach(session.mascotas) { mascota in
                        PHMascotaCard(
                            mascota,
                            onTap: { sheetActivo = .verFicha(mascota) },
                            onEditar: { sheetActivo = .editarMascota(mascota) },
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

    // Favoritos, Anfitrión (Mis hospedajes) y Admin viven ACÁ adentro, y no como pestañas
    // propias — ver el comentario largo en App/RootView.swift sobre por qué (la pestaña
    // automática "Más" de iOS, apenas hay más de 4-5 pestañas, hace que los `.sheet` de esa
    // pantalla dejen de abrir de forma confiable).
    private var seccionCuenta: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text("Cuenta")
                .phText(PHFont.titleMD, color: PHColor.ink)
            NavigationLink {
                FavoritosView()
            } label: {
                filaCuenta("Favoritos", icono: "heart")
            }

            if session.usuario?.esAnfitrion == true {
                NavigationLink {
                    MisHospedajesView()
                } label: {
                    filaCuenta("Mis hospedajes", icono: "building.2.fill")
                }
            }

            if session.usuario?.rol == .admin {
                NavigationLink {
                    AdminView()
                } label: {
                    filaCuenta("Panel de administrador", icono: "shield.fill", contador: session.solicitudesPendientes)
                }
            }

            if session.usuario?.esAnfitrion == false {
                conviertete
            }
        }
    }

    /// Aditivo: activar la capacidad de anfitrión requiere pasar por la verificación de
    /// seguridad primero (ver VerificacionAnfitrionView) — no hay atajo directo. La MISMA
    /// cuenta gana la capacidad, no se crea otra ni se cierra la sesión actual.
    ///
    /// `Button` + `mostrarVerificacion`, no `NavigationLink`: así este botón y la entrada
    /// automática de después del registro comparten el mismo mecanismo de apertura/cierre
    /// (un solo interruptor dueño de PerfilView) — ver el `.navigationDestination` de arriba.
    private var conviertete: some View {
        Button {
            mostrarVerificacion = true
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

    private func filaCuenta(_ titulo: String, icono: String, contador: Int = 0) -> some View {
        HStack {
            Image(systemName: icono).foregroundStyle(PHColor.primary)
            Text(titulo).phText(PHFont.bodyMD, color: PHColor.ink)
            Spacer()
            if contador > 0 {
                PHBadge("\(contador)", style: .warning)
            }
            Image(systemName: "chevron.right").foregroundStyle(PHColor.mutedSoft).font(.caption)
        }
        .padding(PHSpacing.s12)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }
}
