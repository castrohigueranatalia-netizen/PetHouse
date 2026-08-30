//
//  BuscadorSheet.swift
//  Features/Search
//
//  Los 3 campos prominentes de la búsqueda (ver BuscarView): localidad, fechas y
//  convivencia. Separado del "Filtros" avanzado (FiltrosView: tipo, orden, cerca de mí)
//  a propósito — mismo patrón que Airbnb: la barra principal es Dónde/Cuándo/Con quién,
//  todo lo demás es secundario. "Dónde" es un Picker de localidad, no texto libre — la
//  app es solo de Bogotá, segmentada por sus 20 localidades (ver Localidad.swift).
//
//  Los 3 campos viven en UNA sola sección (no tres separadas) para que se sientan parte
//  de una misma selección — Localidad y Convivencia colapsan a una fila cada una
//  (`.navigationLink`, igual que FiltrosView) en vez de desplegar la lista completa ahí
//  mismo, así entran los 3 sin que la hoja se sienta como tres formularios distintos.
//

import SwiftUI

struct BuscadorSheet: View {
    @Bindable var viewModel: BuscarViewModel
    let alBuscar: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// El calendario (PHSelectorRangoFechas) se abre en su PROPIA hoja, no adentro de este
    /// `Form` — puesto directo en una `Section` (como se hizo primero) el botón de "mes
    /// siguiente" dejaba de responder: un `Form`/`List` en iOS puede confundir los toques de
    /// varios botones propios (flechas de mes + los 42 días de la grilla) cuando viven
    /// dentro de una sola fila. Afuera del Form, en un ScrollView normal, es el mismo
    /// componente que ya funciona bien en NuevaReservaView/BloquearFechasSheet.
    @State private var mostrarCalendario = false
    /// Igual que en `NuevaReservaView` — separado de `viewModel.usarFechas` porque este
    /// decide el modo del selector mientras se está eligiendo, no si la búsqueda ya tiene
    /// fechas confirmadas.
    @State private var mismoDia = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Localidad", selection: $viewModel.localidad) {
                        Text("Toda Bogotá").tag(Localidad?.none)
                        ForEach(Localidad.allCases) { localidad in
                            Text(localidad.etiqueta).tag(Localidad?.some(localidad))
                        }
                    }
                    .pickerStyle(.navigationLink)

                    filaFechas

                    Picker("¿Comparte espacio con otras mascotas?", selection: $viewModel.convivencia) {
                        Text("Cualquiera").tag(Convivencia?.none)
                        ForEach(Convivencia.allCases) { opcion in
                            Text(opcion.etiqueta).tag(Convivencia?.some(opcion))
                        }
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text("Sin elegir fechas, se muestran todos los hospedajes disponibles ahora mismo.")
                }
            }
            .navigationTitle("Buscar hospedaje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // "Quitar selección": vuelve localidad/fechas/convivencia (y el resto de
                    // filtros) a como estaban antes de tocar nada, y re-busca de una vez —
                    // mismo botón que aparece junto a la barra de búsqueda en BuscarView
                    // cuando hay algo elegido, pero accesible también desde acá dentro.
                    PHTextButton("Limpiar", role: .destructive) {
                        viewModel.limpiarFiltros()
                        alBuscar()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PHPrimaryButton("Buscar", systemImage: "magnifyingglass") {
                    alBuscar()
                    dismiss()
                }
                .padding(PHSpacing.s16)
                .background(.bar)
            }
        }
        .onAppear {
            mismoDia = Calendar.current.isDate(viewModel.desde, inSameDayAs: viewModel.hasta)
        }
        .sheet(isPresented: $mostrarCalendario) {
            SelectorFechasBusquedaSheet(viewModel: viewModel, mismoDia: $mismoDia)
        }
    }

    /// Fila "Fechas" con un "+" en vez de un switch — tocarla abre el calendario en su
    /// propia hoja (ver `mostrarCalendario`); una vez elegidas, muestra el rango y una "x"
    /// aparte para quitarlas sin tener que volver a abrir el calendario.
    private var filaFechas: some View {
        HStack {
            Button {
                mostrarCalendario = true
            } label: {
                HStack {
                    Text("Fechas").phText(PHFont.bodyMD, color: PHColor.ink)
                    Spacer()
                    if viewModel.usarFechas {
                        Text("\(PHDate.displayShort.string(from: viewModel.desde)) – \(PHDate.displayShort.string(from: viewModel.hasta))")
                            .phText(PHFont.bodySM, color: PHColor.muted)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                if viewModel.usarFechas {
                    viewModel.usarFechas = false
                } else {
                    mostrarCalendario = true
                }
            } label: {
                Image(systemName: viewModel.usarFechas ? "xmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(viewModel.usarFechas ? PHColor.mutedSoft : PHColor.primary)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Calendario para elegir las fechas de la búsqueda — hoja aparte, no adentro del `Form` de
/// `BuscadorSheet` (ver el comentario de `mostrarCalendario`).
private struct SelectorFechasBusquedaSheet: View {
    @Bindable var viewModel: BuscarViewModel
    @Binding var mismoDia: Bool
    @Environment(\.dismiss) private var dismiss
    /// Solo importa en modo "Por noches": el primer toque en el calendario deja una salida
    /// TENTATIVA (al día siguiente de la llegada) para que se vea el rango mientras se
    /// elige — pero eso no es lo mismo que el huésped haya tocado de verdad cuándo se va.
    /// `false` hasta que confirma la salida con un segundo toque (ver
    /// `PHSelectorRangoFechas.onCambio`); en "Mismo día" un solo toque ya es suficiente.
    @State private var faltaSalida = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s16) {
                    VStack(alignment: .leading, spacing: PHSpacing.s4) {
                        Text("¿Cómo quieres buscar?")
                            .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)

                        Picker("Tipo de búsqueda", selection: $mismoDia) {
                            Text("Por noches").tag(false)
                            Text("Por día").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: mismoDia) { _, nuevo in
                            if nuevo { viewModel.hasta = viewModel.desde }
                            else if viewModel.hasta <= viewModel.desde {
                                viewModel.hasta = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.desde) ?? viewModel.desde
                            }
                            faltaSalida = false
                        }

                        // Aclaración siempre visible (no solo cuando ya está elegido "Por
                        // día") — una línea por opción, cada una explicando tanto el
                        // concepto como cómo se elige la fecha en el calendario de abajo,
                        // para que "Por día" quede tan clara como "Por noches" y no una
                        // aclaración a medias.
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Por noches: eliges llegada y salida — tu mascota se queda a dormir esas noches.")
                            Text("Por día: eliges una sola fecha — la dejas y la recoges ese mismo día, sin pasar la noche.")
                        }
                        .phText(PHFont.captionSM, color: PHColor.muted)
                    }

                    // Un solo calendario para llegada y salida — tocar un día fija la
                    // llegada y pasa de una a pedir la salida, sin abrir un segundo
                    // selector aparte (mismo componente que ya usa Reservar).
                    PHSelectorRangoFechas(
                        desde: $viewModel.desde, hasta: $viewModel.hasta,
                        soloUnDia: mismoDia, onCambio: { completo in faltaSalida = !completo },
                        diaOcupado: { _ in false }
                    )

                    if !mismoDia && faltaSalida {
                        Text("Falta elegir la fecha de salida — toca otro día para confirmarla.")
                            .phText(PHFont.captionSM, color: PHColor.error)
                    }

                    if mismoDia {
                        // Ver db/35-reserva-mismo-dia.sql — el servidor ya solo devuelve
                        // hospedajes que ofrezcan esa modalidad.
                        Text("Con \"Por día\", solo se muestran hospedajes que ofrecen reservas de un solo día.")
                            .phText(PHFont.captionSM, color: PHColor.muted)
                    }
                }
                .padding(PHSpacing.s16)
            }
            .navigationTitle("Elegir fechas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PHTextButton("Listo") {
                        viewModel.usarFechas = true
                        dismiss()
                    }
                    .disabled(!mismoDia && faltaSalida)
                }
            }
        }
    }
}
