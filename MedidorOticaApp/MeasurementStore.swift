//
//  MeasurementStore.swift
//  MedidorOticaApp
//
//  Created by user942665 on 5/15/25.
//

import SwiftUI

class MeasurementStore: ObservableObject {
    @Published var records: [MeasurementData] = []
    
    init() {
        // Load saved records from UserDefaults (if any)
        if let data = UserDefaults.standard.data(forKey: "measurements"),
           let savedRecords = try? JSONDecoder().decode([MeasurementData].self, from: data) {
            self.records = savedRecords
        }
    }
    
    func addRecord(_ record: MeasurementData) {
        records.append(record)
        saveRecords()
    }
    
    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "measurements")
        }
    }
}
