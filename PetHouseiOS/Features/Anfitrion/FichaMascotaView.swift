//
//  FichaMascotaView.swift
//  Features/Anfitrion
//
//  Ficha completa de una mascota — dos usos:
//   1. El anfitrión la abre desde una solicitud de reserva (ver ReservasRecibidasView) para
//      evaluar si puede aceptarla, de solo lectura (`onEditar` en `nil`).
//   2. El dueño la abre desde su propio Perfil (ver PerfilView) para ver y editar la ficha
//      de su mascota — con `onEditar` presente, aparece el botón "Editar" en la barra.
//  En ambos casos: fotos, edad, raza, tamaño, peso, si tiene vacunas al día y si necesita
//  medicamentos.
//

import SwiftUI

struct FichaMascotaView: View {
    let mascota: Mascota
    /// `nil` = de solo lectura (el anfitrión viendo la mascota de un huésped). Con un
    /// closure, aparece el botón "Editar" — lo usa PerfilView para que el dueño edite su
    /// propia mascota desde acá mismo, sin tener que buscar el ícono de lápiz en la lista.
    var onEditar: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var fotoVisor: FotoVisorItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s20) {
                    if !mascota.fotos.isEmpty {
                        galeria
                    }

                    encabezado

                    seccionDatos

                    seccionSalud

                    if let notas = mascota.notas, !notas.isEmpty {
                        seccionNotas(notas)
                    }
                }
                .padding(PHSpacing.s16)
            }
            .background(PHColor.canvas)
            .navigationTitle("Ficha de la mascota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
                if let onEditar {
                    ToolbarItem(placement: .topBarTrailing) {
                        PHTextButton("Editar") { onEditar() }
                    }
                }
            }
            .fullScreenCover(item: $fotoVisor) { item in
                PHVisorFotos(urls: item.urls, indiceInicial: item.indiceInicial)
            }
        }
    }

    private var galeria: some View {
        TabView {
            ForEach(Array(mascota.fotos.enumerated()), id: \.offset) { index, url in
                Button {
                    fotoVisor = FotoVisorItem(urls: mascota.fotos, indiceInicial: index)
                } label: {
                    PHCachedAsyncImage(urlString: MediaURL.resolver(url), ladoMaximoPt: 500) {
                        Rectangle().fill(PHColor.surfaceStrong)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .tabViewStyle(.page)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private var encabezado: some View {
        HStack(spacing: PHSpacing.s16) {
            ZStack {
                Circle().fill(PHColor.primaryContainer)
                Image(systemName: iconoEspecie)
                    .font(.title)
                    .foregroundStyle(PHColor.onPrimaryContainer)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(mascota.nombre)
                    .phText(PHFont.displaySM, color: PHColor.ink)
                Text(mascota.especie.capitalized)
                    .phText(PHFont.bodySM, color: PHColor.muted)
            }
            Spacer()
        }
    }

    private var seccionDatos: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            Text("Datos")
                .phText(PHFont.titleMD, color: PHColor.ink)
            VStack(spacing: PHSpacing.s8) {
                if let raza = mascota.raza, !raza.isEmpty {
                    fila("Raza", raza)
                }
                if let edad = mascota.edad {
                    fila("Edad", "\(edad) año\(edad == 1 ? "" : "s")")
                }
                if let tamano = mascota.tamanoLegible {
                    fila("Tamaño", tamano)
                }
                if let peso = mascota.pesoKg {
                    fila("Peso", String(format: "%.1f kg", peso))
                }
                if mascota.raza == nil && mascota.edad == nil && mascota.tamano == nil && mascota.pesoKg == nil {
                    Text(
                        onEditar != nil
                            ? "Todavía no agregaste más datos de \(mascota.nombre) — toca \"Editar\" para completarlos."
                            : "El huésped no agregó más datos de \(mascota.nombre)."
                    )
                    .phText(PHFont.bodySM, color: PHColor.mutedSoft)
                }
            }
        }
        .padding(PHSpacing.s16)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private var seccionSalud: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            Text("Salud")
                .phText(PHFont.titleMD, color: PHColor.ink)
            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                HStack {
                    Image(systemName: mascota.vacunasDia ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(mascota.vacunasDia ? PHColor.success : PHColor.mutedSoft)
                    Text(mascota.vacunasDia ? "Vacunas al día" : "Vacunas no confirmadas al día")
                        .phText(PHFont.bodySM.weight(.medium), color: PHColor.ink)
                }
                HStack {
                    Image(systemName: mascota.necesitaMedicamentos ? "pills.fill" : "checkmark")
                        .foregroundStyle(mascota.necesitaMedicamentos ? PHColor.warning : PHColor.success)
                    Text(mascota.necesitaMedicamentos ? "Necesita tomar medicamentos" : "No necesita medicamentos")
                        .phText(PHFont.bodySM.weight(.medium), color: PHColor.ink)
                }
            }
        }
        .padding(PHSpacing.s16)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private func seccionNotas(_ notas: String) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text(mascota.necesitaMedicamentos ? "Detalle de los medicamentos" : "Notas")
                .phText(PHFont.titleMD, color: PHColor.ink)
            Text(notas)
                .phText(PHFont.bodySM, color: PHColor.body)
        }
        .padding(PHSpacing.s16)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private func fila(_ etiqueta: String, _ valor: String) -> some View {
        HStack {
            Text(etiqueta).phText(PHFont.bodySM, color: PHColor.muted)
            Spacer()
            Text(valor).phText(PHFont.bodySM.weight(.medium), color: PHColor.ink)
        }
    }

    private var iconoEspecie: String {
        switch mascota.especie.lowercased() {
        case "perro": "pawprint.fill"
        case "gato": "cat.fill"
        default: "pawprint"
        }
    }
}
