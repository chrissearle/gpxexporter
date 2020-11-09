import HealthKit

class Authorization {
    private enum AuthError: Error {
        case notAvailable
    }
    
    class func authorize(completion: @escaping (Bool, Error?) -> Swift.Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, AuthError.notAvailable)
            return
        }
        
        HKHealthStore().requestAuthorization(toShare: [], read: [HKObjectType.workoutType(), HKSeriesType.workoutRoute()], completion: completion)
    }
}
