//
//  Persistence.swift
//  argus
//
//  Created by Argus Team on 30.01.2026.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Preview context save hatası — sadece geliştirme ortamında görülür
            print("⚠️ Persistence preview save error: \(error)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "argus")
        if inMemory {
            // Preview için güvenli in-memory store URL'i
            if let firstDesc = container.persistentStoreDescriptions.first {
                firstDesc.url = URL(fileURLWithPath: "/dev/null")
            }
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Üretim kodunda fatalError kullanılmaz — hatayı logla, kullanıcıyı bilgilendir
                // Olası nedenler: disk dolu, veri koruması (kilitli cihaz), model migration hatası
                print("🚨 CoreData yüklenemedi: \(error.localizedDescription)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("ArgusCoreDataFailed"),
                    object: error
                )
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
