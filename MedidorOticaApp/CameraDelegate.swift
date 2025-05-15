//
//  CameraDelegate.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/15/25.
//

import SwiftUI

class CameraDelegate: ARCoordinatorDelegate {
    @Binding var progresso: Int
    @Binding var mensagem: String?
    @Binding var seta: String?
    @Binding var historico: [ (Medidas, UIImage) ]
    var dismiss: () -> Void

    init(progresso: Binding<Int>, mensagem: Binding<String?>, seta: Binding<String?>, historico: Binding<[ (Medidas, UIImage) ]>, dismiss: @escaping () -> Void) {
        self._progresso = progresso
        self._mensagem = mensagem
        self._seta = seta
        self._historico = historico
        self.dismiss = dismiss
    }

    func onProgress(_ progress: Int) { progresso = progress }
    func onHint(_ mensagem: String, _ seta: String?) {
        self.mensagem = mensagem
        self.seta = seta
    }
    func onFinish(_ medidas: Medidas, _ imagem: UIImage) {
        self.historico.insert((medidas, imagem), at: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.dismiss() }
    }
    func onFail(_ mensagem: String) { self.mensagem = mensagem }
}
