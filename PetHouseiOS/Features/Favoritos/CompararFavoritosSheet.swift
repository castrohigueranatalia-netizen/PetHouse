//
//  CompararFavoritosSheet.swift
//  Features/Favoritos
//
//  Tabla lado a lado de 2-3 favoritos elegidos en FavoritosView (modo "Comparar") — precio,
//  calificación, tipo y servicios, para decidir entre varios sin tener que abrir cada
//  detalle por separado y volver atrás a comparar de memoria.
//

import SwiftUI

struct CompararFavoritosSheet: View {
    let hospedajes: [Hospedaje]
    @Environment(\.dismiss) private var dismiss

    /// Unión de todos los servicios que ofrece AL MENOS uno de los hospedajes elegidos —
    /// cada fila de la tabla marca con un check cuáles de ellos sí lo tienen.
    private var todosLosServicios: [String] {
        var vistos: [String] = []
        for hospedaje in hospedajes {
            for servicio in hospedaje.servicios ?? [] where !vistos.contains(servicio) {
                vistos.append(servicio)
            }
        }
        return vistos
    }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: PHSpacing.s20, verticalSpacing: PHSpacing.s12) {
                    GridRow {
                        Text("").frame(width: 110, alignment: .leading)
                        ForEach(hospedajes) { hospedaje in
                            Text(hospedaje.titulo)
                                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                                .frame(width: 140, alignment: .leading)
                                .lineLimit(2)
                        }
                    }
                    Divider().gridCellColumns(hospedajes.count + 1)

                    filaTexto("Tipo") { $0.tipo.etiqueta }
                    filaTexto("Precio/noche") { PHFormato.precio($0.precioNoche) }
                    filaTexto("Precio/día") { $0.precioDia.map(PHFormato.precio) ?? "No ofrece" }
                    filaTexto("Calificación") { hospedaje in
                        hospedaje.numResenas ?? 0 > 0
                            ? "★ \(String(format: "%.1f", hospedaje.rating)) (\(hospedaje.numResenas ?? 0))"
                            : "Sin reseñas"
                    }
                    filaTexto("Convivencia") { $0.convivencia?.etiqueta ?? "Cualquiera" }

                    if !todosLosServicios.isEmpty {
                        Divider().gridCellColumns(hospedajes.count + 1)
                        GridRow {
                            Text("Servicios")
                                .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                            ForEach(hospedajes) { _ in Text("") }
                        }
                        ForEach(todosLosServicios, id: \.self) { servicio in
                            GridRow {
                                Text(servicio)
                                    .phText(PHFont.captionSM, color: PHColor.body)
                                    .frame(width: 110, alignment: .leading)
                                ForEach(hospedajes) { hospedaje in
                                    Image(systemName: (hospedaje.servicios ?? []).contains(servicio) ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle((hospedaje.servicios ?? []).contains(servicio) ? PHColor.success : PHColor.mutedSoft)
                                        .frame(width: 140, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .padding(PHSpacing.s16)
            }
            .navigationTitle("Comparar favoritos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func filaTexto(_ etiqueta: String, _ valor: @escaping (Hospedaje) -> String) -> some View {
        GridRow {
            Text(etiqueta)
                .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                .frame(width: 110, alignment: .leading)
            ForEach(hospedajes) { hospedaje in
                Text(valor(hospedaje))
                    .phText(PHFont.bodySM, color: PHColor.ink)
                    .frame(width: 140, alignment: .leading)
            }
        }
    }
}
