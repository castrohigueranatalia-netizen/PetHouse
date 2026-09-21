//
//  SoporteListView.swift
//  Features/Soporte
//

import SwiftUI

/// Una pregunta frecuente fija — autoayuda antes de escribir un ticket, sin depender del
/// servidor ni de que alguien del equipo responda. Contenido real de cómo funciona la app
/// hoy (pago fuera de la app, verificación de anfitrión, etc.), no genérico.
private struct FAQ: Identifiable {
    let id = UUID()
    let pregunta: String
    let respuesta: String
}

private let faqs: [FAQ] = [
    FAQ(
        pregunta: "¿Cómo funciona el pago?",
        respuesta: "El pago se coordina directamente entre tú y el anfitrión/huésped, fuera de la app — PetHouse no cobra ni retiene dinero."
    ),
    FAQ(
        pregunta: "¿Cómo cancelo una reserva?",
        respuesta: "Desde \"Reservas\", toca la reserva y luego \"Cancelar\" — funciona mientras esté pendiente o confirmada."
    ),
    FAQ(
        pregunta: "¿Qué necesito para ser anfitrión?",
        respuesta: "Verificar tu identidad (cédula, antecedentes, fotos de tu vivienda) y un curso de primeros auxilios para mascotas — desde Perfil → \"Conviértete en anfitrión\"."
    ),
    FAQ(
        pregunta: "¿Qué pasa si el anfitrión rechaza mi solicitud?",
        respuesta: "Puedes buscar otro hospedaje disponible — la app te avisa apenas se resuelva tu solicitud."
    ),
    FAQ(
        pregunta: "¿Cómo dejo una reseña?",
        respuesta: "Cuando tu reserva pase a \"Completada\", aparece el botón \"Dejar una reseña\" en Reservas."
    )
]

struct SoporteListView: View {
    @State private var viewModel = SoporteListViewModel()
    @State private var mostrarNuevoTicket = false

    var body: some View {
        content
            .background(PHColor.canvas)
            .navigationTitle("Soporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PHIconButton(systemImage: "plus", accessibilityLabel: "Nuevo ticket") {
                        mostrarNuevoTicket = true
                    }
                }
            }
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
            .sheet(isPresented: $mostrarNuevoTicket) {
                nuevoTicketSheet
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.tickets.isEmpty {
            PHLoadingStateView(mensaje: "Cargando…")
        } else if let error = viewModel.error, viewModel.tickets.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if viewModel.tickets.isEmpty {
            ScrollView {
                VStack(spacing: PHSpacing.s24) {
                    seccionFAQ
                    PHEmptyStateView(
                        systemImage: "bubble.left.and.bubble.right",
                        titulo: "Sin mensajes de soporte",
                        mensaje: "¿No encontraste tu respuesta arriba? Escríbenos y te respondemos acá mismo.",
                        accionTitulo: "Nuevo ticket"
                    ) {
                        mostrarNuevoTicket = true
                    }
                }
                .padding(PHSpacing.s16)
            }
        } else {
            List {
                Section("Preguntas frecuentes") {
                    ForEach(faqs) { faq in
                        DisclosureGroup(faq.pregunta) {
                            Text(faq.respuesta)
                                .phText(PHFont.bodySM, color: PHColor.body)
                        }
                    }
                }
                Section("Tus tickets") {
                    ForEach(viewModel.tickets) { ticket in
                        NavigationLink(value: ticket) {
                            filaTicket(ticket)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: TicketSoporte.self) { ticket in
                TicketDetalleView(ticketId: ticket.id, asuntoInicial: ticket.asunto)
            }
        }
    }

    /// Autoayuda antes de escribir un ticket — mismas preguntas en los dos lugares donde se
    /// muestran (sin tickets todavía, o encima de la lista de tickets existentes).
    private var seccionFAQ: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text("Preguntas frecuentes")
                .phText(PHFont.titleMD, color: PHColor.ink)
            VStack(spacing: 0) {
                ForEach(Array(faqs.enumerated()), id: \.element.id) { indice, faq in
                    DisclosureGroup(faq.pregunta) {
                        Text(faq.respuesta)
                            .phText(PHFont.bodySM, color: PHColor.body)
                            .padding(.top, PHSpacing.s4)
                    }
                    .padding(PHSpacing.s12)
                    if indice < faqs.count - 1 {
                        Divider()
                    }
                }
            }
            .background(PHColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
        }
    }

    private func filaTicket(_ ticket: TicketSoporte) -> some View {
        HStack(spacing: PHSpacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.asunto)
                    .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                Text(PHDate.displayFromTimestamp(ticket.actualizadoEn))
                    .phText(PHFont.captionSM, color: PHColor.muted)
            }
            Spacer()
            PHBadge(
                ticket.estado == "resuelto" ? "Resuelto" : "Abierto",
                style: ticket.estado == "resuelto" ? .success : .warning
            )
        }
        .padding(.vertical, 4)
    }

    private var nuevoTicketSheet: some View {
        NavigationStack {
            Form {
                Section("Asunto") {
                    TextField("Ej. No me llegó el código de verificación", text: $viewModel.nuevoAsunto)
                }
                Section("Mensaje") {
                    TextField("Cuéntanos qué pasó…", text: $viewModel.nuevoMensaje, axis: .vertical)
                        .lineLimit(4...8)
                }
                if let error = viewModel.errorCrear {
                    Text(error.localizedDescription)
                        .phText(PHFont.bodySM, color: PHColor.error)
                }
            }
            .navigationTitle("Nuevo ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { mostrarNuevoTicket = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PHTextButton("Enviar") {
                        Task {
                            if await viewModel.crearTicket() { mostrarNuevoTicket = false }
                        }
                    }
                    .disabled(!viewModel.puedeCrear)
                }
            }
        }
    }
}
