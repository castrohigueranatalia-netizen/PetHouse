//
//  PreferenciasAnfitrionViewModel.swift
//  Features/Anfitrion
//
//  Paso 2 de "Conviértete en anfitrión" (después de VerificacionAnfitrionViewModel):
//  qué especie, modalidad (días/horas) y tamaño de mascota prefiere cuidar. Multi-selección
//  real (un anfitrión puede aceptar perros Y gatos) — ver db/06-verificacion-anfitrion.sql.
//

import Foundation

@MainActor
@Observable
public final class PreferenciasAnfitrionViewModel {
    public var especies: Set<EspecieCuidado> = []
    public var modalidades: Set<ModalidadCuidado> = []
    public var tamanos: Set<TamanoMascota> = []

    public private(set) var isLoading = false
    public private(set) var errorGeneral: String?
    public private(set) var enviado = false

    private let anfitrionService: AnfitrionServicing

    public init(anfitrionService: AnfitrionServicing = AnfitrionService()) {
        self.anfitrionService = anfitrionService
    }

    public var puedeEnviar: Bool {
        !especies.isEmpty && !modalidades.isEmpty && !tamanos.isEmpty && !isLoading
    }

    public func alternar(_ especie: EspecieCuidado) { toggle(&especies, especie) }
    public func alternar(_ modalidad: ModalidadCuidado) { toggle(&modalidades, modalidad) }
    public func alternar(_ tamano: TamanoMascota) { toggle(&tamanos, tamano) }

    private func toggle<T: Hashable>(_ conjunto: inout Set<T>, _ valor: T) {
        if conjunto.contains(valor) { conjunto.remove(valor) } else { conjunto.insert(valor) }
    }

    public func enviar() async {
        errorGeneral = nil
        guard puedeEnviar else {
            errorGeneral = "Elige al menos una opción en cada pregunta."
            return
        }

        isLoading = true
        defer { isLoading = false }

        let payload = EnviarPreferenciasRequest(
            especies: Array(especies), modalidades: Array(modalidades), tamanos: Array(tamanos)
        )
        do {
            _ = try await anfitrionService.enviarPreferencias(payload)
            enviado = true
        } catch let appError as AppError {
            errorGeneral = appError.localizedDescription
        } catch {
            errorGeneral = error.localizedDescription
        }
    }
}
