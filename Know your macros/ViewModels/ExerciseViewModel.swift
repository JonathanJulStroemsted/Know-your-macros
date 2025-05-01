import Foundation
import Combine

class ExerciseViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var selectedExercises: [UserExercise] = [] {
        didSet {
            print("Updated selectedExercises: \(selectedExercises.count) exercises")
        }
    }
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var errorMessage: String?
    
    private let exerciseService = ExerciseService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                guard let self = self else { return }
                
                if !searchText.isEmpty {
                    self.searchExercises(query: searchText)
                } else {
                    self.loadExercises()
                }
            }
            .store(in: &cancellables)
        
        // Load exercises immediately
        loadExercises()
    }
    
    func loadExercises() {
        isLoading = true
        errorMessage = nil
        
        exerciseService.fetchExercises()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    print("Error loading exercises: \(error)")
                    self?.errorMessage = "Failed to load exercises: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] result in
                self?.isLoading = false
                self?.exercises = result.exercises
                self?.errorMessage = nil
            })
            .store(in: &cancellables)
    }
    
    func searchExercises(query: String) {
        isLoading = true
        errorMessage = nil
        
        exerciseService.searchExercises(query: query)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to search exercises: \(error.localizedDescription)"
                    print("Error searching exercises: \(error)")
                }
            }, receiveValue: { [weak self] result in
                self?.exercises = result.exercises
                self?.isLoading = false
            })
            .store(in: &cancellables)
    }
    
    func addExercise(_ exercise: Exercise, date: Date) {
        let userExercise = UserExercise(exercise: exercise, date: date)
        selectedExercises.append(userExercise)
    }
    
    func removeExercise(at index: Int) {
        guard index < selectedExercises.count else { return }
        selectedExercises.remove(at: index)
    }
    
    func updateExercise(at index: Int, sets: Int? = nil, reps: Int? = nil, weight: Double? = nil, notes: String? = nil) {
        guard index < selectedExercises.count else { return }
        
        var exercise = selectedExercises[index]
        
        if let sets = sets {
            exercise.sets = sets
        }
        
        if let reps = reps {
            exercise.reps = reps
        }
        
        if let weight = weight {
            exercise.weight = weight
        }
        
        if let notes = notes {
            exercise.notes = notes
        }
        
        selectedExercises[index] = exercise
    }
    
    func isExerciseSelected(_ exercise: Exercise) -> Bool {
        selectedExercises.contains { $0.exercise.id == exercise.id }
    }
} 