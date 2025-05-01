import Foundation
import Combine

// Result type to include both exercises and pagination info
struct ExerciseResult {
    let exercises: [Exercise]
    let nextPage: String?
}

class ExerciseService {
    private let localService = LocalExerciseService()
    
    // Fetch exercises (now simply delegating to local service)
    func fetchExercises() -> AnyPublisher<ExerciseResult, Error> {
        return localService.fetchExercises()
    }
    
    // No more paging, all data is local - but keeping the interface consistent
    func fetchNextPage(nextURL: String) -> AnyPublisher<ExerciseResult, Error> {
        // Return empty result as we don't have pagination with local data
        return Just(ExerciseResult(exercises: [], nextPage: nil))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // Search exercises in local database
    func searchExercises(query: String, language: Int = 2) -> AnyPublisher<ExerciseResult, Error> {
        return localService.searchExercises(query: query)
    }
} 