//
//  PHSelectorRangoFechas.swift
//  DesignSystem/Components
//
//  Selector de llegada/salida en forma de calendario mensual, con los días ya ocupados
//  del hospedaje sombreados y sin poder elegirse — reemplaza los dos `DatePicker` sueltos
//  que tenía NuevaReservaView, que no tenían forma de mostrar qué fechas evitar (el huésped
//  solo se enteraba del conflicto al intentar confirmar). `diaOcupado` lo evalúa quien use
//  este componente (ver NuevaReservaViewModel.diaOcupado), así que no depende de Networking.
//
//  Interacción tipo Airbnb: tocar un día fija la llegada (y una salida tentativa al día
//  siguiente); tocar un día posterior fija la salida y cierra la selección; tocar un día
//  anterior a la llegada actual, o uno que dejaría un día ocupado en medio del rango,
//  reinicia la selección desde ese día.
//

import SwiftUI

public struct PHSelectorRangoFechas: View {
    @Binding var desde: Date
    @Binding var hasta: Date
    let diaOcupado: (Date) -> Bool
    /// `true` para elegir un solo día (entrega y recogida el mismo día, ver
    /// NuevaReservaViewModel.mismoDia) — tocar un día lo fija de una vez como `desde` Y
    /// `hasta`, sin el paso de "ahora toca la salida" de la selección de rango normal.
    let soloUnDia: Bool
    /// Avisa, después de cada toque, si la selección ya quedó COMPLETA (`true`) o si todavía
    /// falta confirmar la salida (`false` — el primer toque ya deja una `hasta` tentativa al
    /// día siguiente, pero eso no es lo mismo que el huésped haya elegido de verdad cuándo se
    /// va). Con `soloUnDia` siempre es `true`, un solo toque alcanza. Quien use este selector
    /// decide qué hacer con eso (ver `BuscadorSheet`, que no deja confirmar la búsqueda "Por
    /// noches" sin una salida real).
    var onCambio: ((Bool) -> Void)? = nil

    @State private var mesMostrado: Date
    @State private var seleccionandoSalida = false

    private static let formatoMes: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private static let diasSemana = ["L", "M", "M", "J", "V", "S", "D"]
    private let calendario = Calendar.current

    public init(
        desde: Binding<Date>, hasta: Binding<Date>, soloUnDia: Bool = false,
        onCambio: ((Bool) -> Void)? = nil, diaOcupado: @escaping (Date) -> Bool
    ) {
        self._desde = desde
        self._hasta = hasta
        self.soloUnDia = soloUnDia
        self.onCambio = onCambio
        self.diaOcupado = diaOcupado
        self._mesMostrado = State(initialValue: desde.wrappedValue)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            resumenFechas
            selectorMes
            grilla
            leyenda
        }
    }

    private var resumenFechas: some View {
        HStack(spacing: PHSpacing.s16) {
            if soloUnDia {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Fecha").phText(PHFont.captionSM, color: PHColor.muted)
                    Text(PHDate.display.string(from: desde)).phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Llegada").phText(PHFont.captionSM, color: PHColor.muted)
                    Text(PHDate.display.string(from: desde)).phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                }
                Image(systemName: "arrow.right").foregroundStyle(PHColor.mutedSoft)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Salida").phText(PHFont.captionSM, color: PHColor.muted)
                    Text(PHDate.display.string(from: hasta)).phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                }
            }
            Spacer()
        }
    }

    private var selectorMes: some View {
        HStack {
            PHIconButton(systemImage: "chevron.left", accessibilityLabel: "Mes anterior") {
                mesMostrado = calendario.date(byAdding: .month, value: -1, to: mesMostrado) ?? mesMostrado
            }
            Spacer()
            Text(Self.formatoMes.string(from: mesMostrado).capitalized)
                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
            Spacer()
            PHIconButton(systemImage: "chevron.right", accessibilityLabel: "Mes siguiente") {
                mesMostrado = calendario.date(byAdding: .month, value: 1, to: mesMostrado) ?? mesMostrado
            }
        }
    }

    private var grilla: some View {
        VStack(spacing: PHSpacing.s8) {
            HStack {
                ForEach(Array(Self.diasSemana.enumerated()), id: \.offset) { _, letra in
                    Text(letra)
                        .frame(maxWidth: .infinity)
                        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: PHSpacing.s8) {
                ForEach(Array(CalendarioMes.diasDeLaGrilla(paraMes: mesMostrado, calendario: calendario).enumerated()), id: \.offset) { _, dia in
                    if let dia {
                        casillaDia(dia)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
    }

    private func casillaDia(_ dia: Date) -> some View {
        let ocupado = diaOcupado(dia) || dia < calendario.startOfDay(for: .now)
        let esInicio = calendario.isDate(dia, inSameDayAs: desde)
        let esFin = calendario.isDate(dia, inSameDayAs: hasta)
        let enRango = dia > desde && dia < hasta
        let numero = calendario.component(.day, from: dia)

        return Button {
            tocar(dia)
        } label: {
            Text("\(numero)")
                .strikethrough(ocupado)
                .phText(
                    PHFont.bodySM.weight(esInicio || esFin ? .semibold : .regular),
                    color: ocupado ? PHColor.mutedSoft : (esInicio || esFin ? .white : PHColor.ink)
                )
                .frame(width: 36, height: 36)
                .background(esInicio || esFin ? PHColor.primary : (enRango ? PHColor.primaryContainer : .clear))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(ocupado)
        .accessibilityLabel(ocupado ? "Día \(numero), no disponible" : "Día \(numero)")
    }

    private var leyenda: some View {
        HStack(spacing: PHSpacing.s4) {
            Text("—").strikethrough().phText(PHFont.captionSM, color: PHColor.mutedSoft)
            Text("No disponible").phText(PHFont.captionSM, color: PHColor.muted)
        }
    }

    private func tocar(_ dia: Date) {
        if soloUnDia {
            desde = dia
            hasta = dia
            onCambio?(true)
            return
        }
        if !seleccionandoSalida || dia <= desde || hayOcupadoEntre(desde, dia) {
            desde = dia
            hasta = calendario.date(byAdding: .day, value: 1, to: dia) ?? dia
            seleccionandoSalida = true
            onCambio?(false)
        } else {
            hasta = dia
            seleccionandoSalida = false
            onCambio?(true)
        }
    }

    private func hayOcupadoEntre(_ inicio: Date, _ fin: Date) -> Bool {
        var cursor = inicio
        while cursor < fin {
            if diaOcupado(cursor) { return true }
            guard let siguiente = calendario.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = siguiente
        }
        return false
    }
}
