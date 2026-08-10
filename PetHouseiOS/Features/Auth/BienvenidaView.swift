//
//  BienvenidaView.swift
//  Features/Auth
//
//  Primer fork de la app para quien no tiene sesión: elegir el rol ANTES de pedir datos,
//  no mezclado con el formulario de login (que no lo necesita — inicia sesión con
//  correo+contraseña, el rol ya quedó fijo al registrarse). Mismo patrón que Airbnb
//  (host vs. guest) o Uber Eats (pedir vs. repartir): la decisión se toma una sola vez,
//  con dos opciones grandes y claras, antes de cualquier campo de texto.
//
//  "Ya tengo cuenta" evita que alguien que vuelve tenga que pasar por este fork cada vez
//  — va directo al login de siempre.
//

import SwiftUI

struct BienvenidaView: View {
    @State private var mostrarRegistro = false
    @State private var mostrarLogin = false
    @State private var rolElegido: Usuario.Rol = .cliente

    var body: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s32) {
            Spacer()

            VStack(alignment: .leading, spacing: PHSpacing.s16) {
                PHLogo(height: 64)
                Text("Bienvenido a PetHouse")
                    .phText(PHFont.displayLG, color: PHColor.ink)
                Text("¿Qué quieres hacer?")
                    .phText(PHFont.bodyMD, color: PHColor.muted)
            }

            VStack(spacing: PHSpacing.s12) {
                PHPrimaryButton("Busco hospedaje para mi mascota", systemImage: "pawprint.fill") {
                    rolElegido = .cliente
                    mostrarRegistro = true
                }
                PHSecondaryButton("Quiero ofrecer hospedaje", systemImage: "house.fill") {
                    rolElegido = .anfitrion
                    mostrarRegistro = true
                }
            }

            Spacer()

            HStack {
                Text("¿Ya tienes cuenta?")
                    .phText(PHFont.bodySM, color: PHColor.muted)
                PHTextButton("Iniciar sesión") { mostrarLogin = true }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(PHSpacing.s24)
        .background(PHColor.canvas)
        .navigationDestination(isPresented: $mostrarRegistro) {
            RegistroView(rolInicial: rolElegido)
        }
        .navigationDestination(isPresented: $mostrarLogin) {
            LoginView()
        }
    }
}
