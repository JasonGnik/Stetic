import Foundation
import HealthKit

// Apple Health: read today's steps, read/write bodyweight. Best-effort — no-ops
// gracefully when Health is unavailable or permission is denied.
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    private var stepType: HKQuantityType? { HKQuantityType.quantityType(forIdentifier: .stepCount) }
    private var massType: HKQuantityType? { HKQuantityType.quantityType(forIdentifier: .bodyMass) }

    func requestAuth() async {
        guard available else { return }
        var read = Set<HKObjectType>()
        if let s = stepType { read.insert(s) }
        if let m = massType { read.insert(m) }
        var share = Set<HKSampleType>()
        if let m = massType { share.insert(m) }
        try? await store.requestAuthorization(toShare: share, read: read)
    }

    func todaySteps() async -> Int {
        guard available, let type = stepType else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
            }
            store.execute(q)
        }
    }

    func saveWeight(kg: Double) async {
        guard available, let type = massType else { return }
        let q = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: type, quantity: q, start: Date(), end: Date())
        try? await store.save(sample)
    }

    func latestWeightKg() async -> Double? {
        guard available, let type = massType else { return nil }
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo)))
            }
            store.execute(q)
        }
    }
}
