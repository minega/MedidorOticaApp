//
//  ContentView.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/9/25.
//
import SwiftUI
import Combine

// Navegação entre telas
enum Step { case welcome, camera, review, manual }

struct ContentView: View {

    // MARK: – Navegação
    @State var step: Step = .welcome       // var (não private) → Preview

    // MARK: – Medidas e mensagens
    @State private var meas = MeasurementData.empty
    @State private var alignMsg = ""
    @State private var eyeMsg   = ""

    // MARK: – Estado de captura
    @State private var useFront = false
    @State private var flashOn  = false
    @State private var autoCap  = false

    // MARK: – Histórico
    @State private var name     = ""
    @State private var history: [Record] = []
    @State private var showHist = false

    // MARK: – Ajuste manual
    @State private var dragPts: [CGPoint] = []

    // Combine → recebe Record gerado pelo ARViewContainer
    private let sub = ARViewContainer.publisher.receive(on: RunLoop.main)

    var body: some View {
        ZStack {
            switch step {
            case .welcome: WelcomeView
            case .camera:  CameraView
            case .review:  ReviewView
            case .manual:  ManualAdjustView
            }
        }
        .onReceive(sub) { rec in            // recebeu captura
            meas = rec.data
            step = .review
        }
    }

    // MARK: – 1. Welcome
    private var WelcomeView: some View {
        ZStack {
            Image("fundo")
                .resizable().scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                Text("Ótica Manzolli")
                    .font(.largeTitle.weight(.bold))
                    .shadow(radius: 5)

                Button("Tirar Medidas") { step = .camera }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 55)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal, 40)

                Toggle("Captura Automática", isOn: $autoCap)
                    .padding(.horizontal, 60)

                Spacer()

                Button("Ver Histórico") { showHist = true }
                    .padding(.horizontal, 30).padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showHist) {
            HistorySheet(history: $history)
        }
    }

    // MARK: – 2. Câmera
    private var CameraView: some View {
        ZStack {
            ARViewContainer(useFront:  useFront,
                            flashOn:   $flashOn,
                            autoCapOn: $autoCap,
                            data:      $meas,
                            alignMsg:  $alignMsg,
                            eyeMsg:    $eyeMsg)
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack(spacing: 20) {
                    // trocar câmera
                    Button(action: { useFront.toggle() }) {
                        Image(systemName: "camera.rotate")
                    }

                    // flash on/off
                    Button(action: { flashOn.toggle() }) {
                        Image(systemName: flashOn ? "bolt.fill" : "bolt.slash")
                    }
                }
                .buttonStyle(.plain)
                .font(.title2)
                .padding(10)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .padding(.top, 10)

                Spacer()

                if !alignMsg.isEmpty || !eyeMsg.isEmpty {
                    VStack(spacing: 4) {
                        if !alignMsg.isEmpty { Text(alignMsg) }
                        if !eyeMsg.isEmpty   { Text(eyeMsg)   }
                    }
                    .padding(8)
                    .background(.black.opacity(0.6))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    // MARK: – 3. Relatório
    private var ReviewView: some View {
        ScrollView {
            VStack(spacing: 20) {

                Image(uiImage: ARViewContainer.lastSnapshot)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 260)
                    .cornerRadius(12)

                metricTable

                TextField("Nome do cliente", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)

                HStack(spacing: 20) {
                    Button("Ajuste Manual") { step = .manual }
                    Button("Salvar & Compartilhar") { saveAndShare() }
                        .buttonStyle(.borderedProminent)
                }

                Button("Refazer", role: .destructive) { step = .camera }
            }
            .padding()
        }
    }
    private var metricTable: some View {
        let items: [(String, Float)] = [
            ("DP",        meas.dp),
            ("ALT",       meas.alt),
            ("Vertical",  meas.vertical),
            ("Horizontal",meas.horizontal),
            ("Diagonal",  meas.diagonal),
            ("Ponte",     meas.ponte)
        ]
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.0) { label, value in
                Text("\\(label): \\(value, specifier: \"%.1f\") mm")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: – 4. Ajuste manual
    private var ManualAdjustView: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: ARViewContainer.lastSnapshot)
                    .resizable().scaledToFit()
                    .overlay(DraggableOverlay(points: $dragPts))

                VStack {
                    Spacer()
                    Button("OK") {
                        recalcFromDrag()
                        step = .review
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .onAppear {
                if dragPts.isEmpty { initDragPoints(size: geo.size) }
            }
        }
    }
    private func initDragPoints(size: CGSize) {
        let w = size.width, h = size.height
        dragPts = [
            CGPoint(x: w*0.25, y: h*0.25),
            CGPoint(x: w*0.75, y: h*0.25),
            CGPoint(x: w*0.25, y: h*0.75),
            CGPoint(x: w*0.75, y: h*0.75)
        ]
    }
    private func recalcFromDrag() {
        guard dragPts.count == 4 else { return }

        let pxH = hypot(dragPts[1].x - dragPts[0].x,
                        dragPts[1].y - dragPts[0].y)
        guard pxH > 0 else { return }

        let mmPerPx = meas.horizontal / Float(pxH)

        meas.horizontal = Float(pxH) * mmPerPx
        let pxV = hypot(dragPts[2].x - dragPts[0].x,
                        dragPts[2].y - dragPts[0].y)
        meas.vertical   = Float(pxV) * mmPerPx
        let pxD = hypot(dragPts[2].x - dragPts[1].x,
                        dragPts[2].y - dragPts[1].y)
        meas.diagonal   = Float(pxD) * mmPerPx
    }

    // MARK: – Salvar + compartilhar
    private func saveAndShare() {
        let rec = Record(name: name.isEmpty ? "(Sem nome)" : name,
                         snapshot: ARViewContainer.lastSnapshot,
                         data: meas)
        history.insert(rec, at: 0)
        name = ""
        step = .welcome

        let av = UIActivityViewController(activityItems: [rec.snapshot],
                                          applicationActivities: nil)
        UIApplication.shared.firstKeyWindow?
            .rootViewController?
            .present(av, animated: true)
    }
}

// MARK: – Histórico
struct HistorySheet: View {
    @Binding var history: [Record]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(history) { r in
                HStack {
                    Image(uiImage: r.snapshot)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                    VStack(alignment: .leading) {
                        Text(r.name).bold()
                        Text(DateFormatter.localizedString(from: r.date,
                                                            dateStyle: .short,
                                                            timeStyle: .short))
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Histórico")
            .toolbar { Button("Fechar") { dismiss() } }
        }
    }
}

// MARK: – Preview
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(step: .welcome)              // força só a tela inicial
            .previewDevice("iPhone 15 Pro")
    }
}
#endif
