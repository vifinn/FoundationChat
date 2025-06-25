# Structured Output with @Generable

## Basic @Generable Types

```swift
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct Recipe {
    let name: String
    let ingredients: [String]
    let instructions: [String]
    let prepTime: Int // in minutes
    let difficulty: Difficulty
    
    @Generable
    enum Difficulty {
        case easy
        case medium
        case hard
    }
}

// Usage
func generateRecipe(for dish: String) async throws -> Recipe {
    let session = LanguageModelSession()
    let response = try await session.respond(
        to: "Create a recipe for \(dish)",
        generating: Recipe.self
    )
    return response.content
}
```

## Using @Guide Annotations

```swift
@available(iOS 26.0, *)
@Generable
struct MovieReview {
    @Guide(description: "A catchy title for the review")
    let title: String
    
    @Guide(description: "Brief plot summary without spoilers")
    let summary: String
    
    @Guide(.range(1...10))
    let rating: Int
    
    @Guide(.count(3))
    let pros: [String]
    
    @Guide(.count(3))
    let cons: [String]
    
    let recommendation: Recommendation
    
    @Generable
    enum Recommendation {
        case mustWatch
        case worthWatching
        case skipIt
    }
}
```

## Complex Nested Structures

```swift
@available(iOS 26.0, *)
@Generable
struct TravelItinerary {
    @Guide(description: "Trip title with destination")
    let title: String
    
    @Guide(description: "Brief overview of the trip")
    let description: String
    
    @Guide(.count(5))
    let days: [DayPlan]
    
    let estimatedBudget: Budget
    
    @Generable
    struct DayPlan {
        @Guide(description: "Day number and theme")
        let title: String
        
        @Guide(.count(3...5))
        let activities: [Activity]
        
        let meals: Meals
    }
    
    @Generable
    struct Activity {
        let name: String
        let duration: String
        let cost: String
        let category: Category
        
        @Generable
        enum Category {
            case sightseeing
            case adventure
            case cultural
            case relaxation
            case shopping
        }
    }
    
    @Generable
    struct Meals {
        let breakfast: String
        let lunch: String
        let dinner: String
    }
    
    @Generable
    struct Budget {
        let accommodation: String
        let food: String
        let activities: String
        let transportation: String
        let total: String
    }
}
```

## Regex Guides

```swift
@available(iOS 26.0, *)
@Generable
struct Contact {
    @Guide(Regex {
        Capture {
            ChoiceOf {
                "Mr"
                "Mrs"
                "Ms"
                "Dr"
            }
        }
        ". "
        OneOrMore(.word)
    })
    let name: String
    
    @Guide(Regex {
        Capture {
            Repeat(3) { .digit }
        }
        "-"
        Capture {
            Repeat(3) { .digit }
        }
        "-"
        Capture {
            Repeat(4) { .digit }
        }
    })
    let phoneNumber: String
    
    @Guide(description: "Professional email address")
    let email: String
}
```

## Optional Properties

```swift
@available(iOS 26.0, *)
@Generable
struct ProductDescription {
    let name: String
    let category: String
    let price: Double
    
    // Optional properties
    let discount: Double?
    let features: [String]?
    let warranty: String?
    
    @Guide(description: "Generate only if product is electronic")
    let technicalSpecs: TechnicalSpecs?
    
    @Generable
    struct TechnicalSpecs {
        let processor: String?
        let memory: String?
        let storage: String?
        let battery: String?
    }
}
```

## Performance Optimization

```swift
@available(iOS 26.0, *)
class OptimizedGenerator {
    private let session: LanguageModelSession
    private var hasGeneratedBefore = false
    
    init() {
        session = LanguageModelSession(instructions: """
            Generate product descriptions for an e-commerce platform.
            Focus on key features and benefits.
            
            Example output:
            {
                "name": "Wireless Headphones Pro",
                "category": "Electronics",
                "price": 299.99,
                "features": ["Active noise cancellation", "30-hour battery", "Premium sound"]
            }
            """)
    }
    
    func generateProduct(prompt: String) async throws -> ProductDescription {
        // After first generation, we can skip schema inclusion
        let options = GenerationOptions(temperature: 0.7)
        
        let response = try await session.respond(
            to: prompt,
            generating: ProductDescription.self,
            includeSchemaInPrompt: !hasGeneratedBefore,
            options: options
        )
        
        hasGeneratedBefore = true
        return response.content
    }
}
```