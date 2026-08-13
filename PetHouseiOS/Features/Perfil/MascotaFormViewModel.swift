//
//  MascotaFormViewModel.swift
//  Features/Perfil
//

import Foundation

@MainActor
@Observable
public final class MascotaFormViewModel {
    public enum Resultado: Equatable {
        case ninguno, exito, pendienteBackend, error(String)
    }

    /// `nil` = creando una mascota nueva; con valor = editando una existente.
    public let mascotaExistente: Mascota?

    public var nombre: String
    public var especie: String
    public var raza: String
    public var edad: String
    public var tamano: String?
    public var pesoKg: String
    public var vacunasDia: Bool
    public var necesitaMedicamentos: Bool
    public var notas: String

    public private(set) var isLoading = false
    public private(set) var resultado: Resultado = .ninguno

    private let service: MascotasServicing
    private let session: SessionStore

    public init(mascota: Mascota?, session: SessionStore, service: MascotasServicing = MascotasService()) {
        self.mascotaExistente = mascota
        self.session = session
        self.service = service
        self.nombre = mascota?.nombre ?? ""
        self.especie = mascota?.especie ?? "perro"
        self.raza = mascota?.raza ?? ""
        self.edad = mascota?.edad.map { String($0) } ?? ""
        self.tamano = mascota?.tamano
        self.pesoKg = mascota?.pesoKg.map { String($0) } ?? ""
        self.vacunasDia = mascota?.vacunasDia ?? false
        self.necesitaMedicamentos = mascota?.necesitaMedicamentos ?? false
        self.notas = mascota?.notas ?? ""
    }

    public var puedeGuardar: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    public func guardar() async {
        guard puedeGuardar else { return }
        isLoading = true
        resultado = .ninguno
        defer { isLoading = false }

        let payload = GuardarMascotaRequest(
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            especie: especie,
            raza: raza.isEmpty ? nil : raza,
            edad: Int(edad),
            tamano: tamano,
            pesoKg: Double(pesoKg.replacingOccurrences(of: ",", with: ".")),
            vacunasDia: vacunasDia,
            necesitaMedicamentos: necesitaMedicamentos,
            notas: notas.isEmpty ? nil : notas
        )

        do {
            if let existente = mascotaExistente {
                _ = try await service.actualizar(id: existente.id, payload)
            } else {
                _ = try await service.crear(payload)
            }
            resultado = .exito
            await session.refrescarPerfilCompleto()
        } catch let appError as AppError where appError.esFuncionPendiente {
            resultado = .pendienteBackend
        } catch let appError as AppError {
            resultado = .error(appError.localizedDescription)
        } catch {
            resultado = .error(error.localizedDescription)
        }
    }
}
