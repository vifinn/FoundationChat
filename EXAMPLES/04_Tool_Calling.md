# Tool Calling Examples

## Basic Tool Implementation

```swift
import FoundationModels
import Contacts

@available(iOS 26.0, *)
struct ContactSearchTool: Tool {
    let name = "searchContacts"
    let description = "Searches the user's contacts for people matching the given criteria"
    
    @Generable
    struct Arguments {
        let searchQuery: String
        let searchType: SearchType
        
        @Generable
        enum SearchType {
            case byName
            case byCompany
            case byPhoneNumber
            case byEmail
        }
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        let store = CNContactStore()
        
        // Request access if needed
        let authorized = try await store.requestAccess(for: .contacts)
        guard authorized else {
            return ToolOutput("Contact access not granted")
        }
        
        // Define keys to fetch
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactOrganizationNameKey
        ] as [CNKeyDescriptor]
        
        // Create predicate based on search type
        let predicate: NSPredicate
        switch arguments.searchType {
        case .byName:
            predicate = CNContact.predicateForContacts(matchingName: arguments.searchQuery)
        case .byCompany:
            predicate = CNContact.predicateForContacts(matchingName: arguments.searchQuery)
        case .byEmail:
            predicate = CNContact.predicateForContacts(matchingEmailAddress: arguments.searchQuery)
        case .byPhoneNumber:
            // Clean phone number for search
            let cleaned = arguments.searchQuery.filter { $0.isNumber }
            predicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: cleaned))
        }
        
        // Fetch contacts
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        
        if contacts.isEmpty {
            return ToolOutput("No contacts found matching '\(arguments.searchQuery)'")
        }
        
        // Format results
        let results = contacts.map { contact in
            "\(contact.givenName) \(contact.familyName) - \(contact.organizationName)"
        }.joined(separator: "\n")
        
        return ToolOutput("Found \(contacts.count) contacts:\n\(results)")
    }
}
```

## Weather Tool with External API

```swift
import FoundationModels
import CoreLocation

@available(iOS 26.0, *)
struct WeatherTool: Tool {
    let name = "getWeather"
    let description = "Gets current weather information for a location"
    
    @Generable
    struct Arguments {
        let location: String
        let units: Units
        
        @Generable
        enum Units {
            case celsius
            case fahrenheit
        }
    }
    
    private let apiKey: String
    private let geocoder = CLGeocoder()
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        // Geocode location
        let placemarks = try await geocoder.geocodeAddressString(arguments.location)
        guard let coordinate = placemarks.first?.location?.coordinate else {
            return ToolOutput("Could not find location: \(arguments.location)")
        }
        
        // Build API URL
        let unitParam = arguments.units == .celsius ? "metric" : "imperial"
        let url = URL(string: """
            https://api.openweathermap.org/data/2.5/weather?\
            lat=\(coordinate.latitude)&\
            lon=\(coordinate.longitude)&\
            units=\(unitParam)&\
            appid=\(apiKey)
            """)!
        
        // Fetch weather data
        let (data, _) = try await URLSession.shared.data(from: url)
        let weather = try JSONDecoder().decode(WeatherResponse.self, from: data)
        
        // Format response
        let unitSymbol = arguments.units == .celsius ? "°C" : "°F"
        return ToolOutput("""
            Weather in \(weather.name):
            Temperature: \(weather.main.temp)\(unitSymbol)
            Feels like: \(weather.main.feelsLike)\(unitSymbol)
            Conditions: \(weather.weather.first?.description ?? "Unknown")
            Humidity: \(weather.main.humidity)%
            """)
    }
}

// Weather API Response Models
struct WeatherResponse: Codable {
    let name: String
    let main: MainWeather
    let weather: [Weather]
}

struct MainWeather: Codable {
    let temp: Double
    let feelsLike: Double
    let humidity: Int
    
    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case humidity
    }
}

struct Weather: Codable {
    let description: String
}
```

## Calendar Event Tool

```swift
import FoundationModels
import EventKit

@available(iOS 26.0, *)
struct CalendarTool: Tool {
    let name = "calendarEvents"
    let description = "Creates, reads, or modifies calendar events"
    
    @Generable
    struct Arguments {
        let action: Action
        let eventDetails: EventDetails?
        
        @Generable
        enum Action {
            case create
            case listToday
            case listWeek
            case findByTitle(String)
        }
        
        @Generable
        struct EventDetails {
            let title: String
            let startDate: String // ISO 8601 format
            let duration: Int // minutes
            let location: String?
            let notes: String?
        }
    }
    
    private let eventStore = EKEventStore()
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        // Request calendar access
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            return ToolOutput("Calendar access not granted")
        }
        
        switch arguments.action {
        case .create:
            return try await createEvent(arguments.eventDetails)
            
        case .listToday:
            return try await listEvents(days: 1)
            
        case .listWeek:
            return try await listEvents(days: 7)
            
        case .findByTitle(let title):
            return try await findEvents(title: title)
        }
    }
    
    private func createEvent(_ details: EventDetails?) async throws -> ToolOutput {
        guard let details = details else {
            return ToolOutput("Event details required for creation")
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = details.title
        
        // Parse date
        let formatter = ISO8601DateFormatter()
        guard let startDate = formatter.date(from: details.startDate) else {
            return ToolOutput("Invalid date format")
        }
        
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(details.duration * 60))
        event.location = details.location
        event.notes = details.notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        try eventStore.save(event, span: .thisEvent)
        
        return ToolOutput("Created event: \(details.title) on \(startDate.formatted())")
    }
    
    private func listEvents(days: Int) async throws -> ToolOutput {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        
        if events.isEmpty {
            return ToolOutput("No events found")
        }
        
        let eventList = events.map { event in
            "\(event.title ?? "Untitled") - \(event.startDate.formatted())"
        }.joined(separator: "\n")
        
        return ToolOutput("Upcoming events:\n\(eventList)")
    }
    
    private func findEvents(title: String) async throws -> ToolOutput {
        // Search in the next 30 days
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
            .filter { $0.title?.localizedCaseInsensitiveContains(title) ?? false }
        
        if events.isEmpty {
            return ToolOutput("No events found matching '\(title)'")
        }
        
        let results = events.map { event in
            """
            Title: \(event.title ?? "Untitled")
            Date: \(event.startDate.formatted())
            Location: \(event.location ?? "No location")
            """
        }.joined(separator: "\n\n")
        
        return ToolOutput("Found \(events.count) events:\n\(results)")
    }
}
```

## Tool with State Management

```swift
import FoundationModels

@available(iOS 26.0, *)
class ShoppingCartTool: Tool {
    let name = "shoppingCart"
    let description = "Manages a shopping cart - add items, remove items, or view cart"
    
    @Generable
    struct Arguments {
        let action: Action
        let item: Item?
        
        @Generable
        enum Action {
            case add
            case remove
            case viewCart
            case clearCart
            case checkout
        }
        
        @Generable
        struct Item {
            let name: String
            let quantity: Int
            let price: Double?
        }
    }
    
    // Maintain cart state
    private var cart: [CartItem] = []
    
    struct CartItem {
        let name: String
        var quantity: Int
        let price: Double
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        switch arguments.action {
        case .add:
            guard let item = arguments.item else {
                return ToolOutput("Item details required to add to cart")
            }
            return addItem(item)
            
        case .remove:
            guard let item = arguments.item else {
                return ToolOutput("Item name required to remove from cart")
            }
            return removeItem(item.name)
            
        case .viewCart:
            return viewCart()
            
        case .clearCart:
            cart.removeAll()
            return ToolOutput("Cart cleared")
            
        case .checkout:
            return checkout()
        }
    }
    
    private func addItem(_ item: Arguments.Item) -> ToolOutput {
        let price = item.price ?? 9.99 // Default price if not provided
        
        if let index = cart.firstIndex(where: { $0.name == item.name }) {
            cart[index].quantity += item.quantity
        } else {
            cart.append(CartItem(name: item.name, quantity: item.quantity, price: price))
        }
        
        return ToolOutput("Added \(item.quantity) \(item.name) to cart")
    }
    
    private func removeItem(_ name: String) -> ToolOutput {
        if let index = cart.firstIndex(where: { $0.name == name }) {
            let removed = cart.remove(at: index)
            return ToolOutput("Removed \(removed.name) from cart")
        }
        return ToolOutput("\(name) not found in cart")
    }
    
    private func viewCart() -> ToolOutput {
        if cart.isEmpty {
            return ToolOutput("Cart is empty")
        }
        
        var output = "Shopping Cart:\n"
        var total = 0.0
        
        for item in cart {
            let subtotal = Double(item.quantity) * item.price
            output += "\(item.name) x\(item.quantity) - $\(String(format: "%.2f", subtotal))\n"
            total += subtotal
        }
        
        output += "\nTotal: $\(String(format: "%.2f", total))"
        return ToolOutput(output)
    }
    
    private func checkout() -> ToolOutput {
        if cart.isEmpty {
            return ToolOutput("Cannot checkout - cart is empty")
        }
        
        let total = cart.reduce(0.0) { $0 + (Double($1.quantity) * $1.price) }
        let itemCount = cart.reduce(0) { $0 + $1.quantity }
        
        // In a real app, this would process payment
        cart.removeAll()
        
        return ToolOutput("""
            Checkout successful!
            Items: \(itemCount)
            Total paid: $\(String(format: "%.2f", total))
            Thank you for your purchase!
            """)
    }
}
```

## Using Multiple Tools

```swift
@available(iOS 26.0, *)
class MultiToolAssistant {
    private let session: LanguageModelSession
    
    init() {
        let tools: [any Tool] = [
            WeatherTool(apiKey: "your-api-key"),
            CalendarTool(),
            ContactSearchTool()
        ]
        
        session = LanguageModelSession(
            tools: tools,
            instructions: """
                You are a helpful personal assistant.
                Use the available tools to help users with:
                - Weather information
                - Calendar management
                - Contact searches
                
                Always provide clear, concise responses.
                If a tool fails, explain the issue politely.
                """
        )
    }
    
    func assist(with request: String) async throws -> String {
        let response = try await session.respond(to: request)
        return response.content
    }
}

// Usage example
let assistant = MultiToolAssistant()
let response = try await assistant.assist(
    with: "What's the weather in San Francisco and do I have any meetings today?"
)
// The model will automatically call both WeatherTool and CalendarTool
```