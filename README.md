# NoteAI - Smart Contact Management App

NoteAI is a minimalist, AI-powered contact management app designed for effortless networking. Capture contacts with natural language, intelligently organize with automatic labeling, and find anyone instantly with smart search.

## Features

- **No Settings Required**: Everything is powered by AI
- **Seamless Contact Creation**: Add contacts with natural language
- **Smart Labeling**: AI automatically categorizes your contacts
- **Intelligent Search**: Find contacts using natural language queries
- **Sync with iPhone Contacts**: Seamlessly works with your existing contacts

## Technologies Used

- SwiftUI for the UI
- Supabase for backend and authentication
- OpenAI for natural language processing
- StoreKit for in-app purchases

## Setup Instructions

### Prerequisites

- Xcode 14.0 or later
- iOS 15.0 or later
- Active Apple Developer account
- Supabase account
- OpenAI API key

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Francescocrivelli/noteai.git
cd noteai
```

2. Set up Supabase:
   - Create a new project on Supabase
   - Run the SQL queries from `Schema/supabase_schema.sql` in the Supabase SQL editor
   - Set up authentication providers (Google and Apple) in the Auth settings
   - Update the Supabase URL and API key in `NoteAIApp.swift`

3. Set up OpenAI:
   - Obtain an API key from OpenAI
   - Update the API key in `NoteAIApp.swift`

4. Configure Apple Sign In:
   - Set up Sign In with Apple capability in Xcode
   - Configure your app in the Apple Developer portal

5. Configure In-App Purchases:
   - Set up products in App Store Connect
   - Update product IDs in `StoreKitService.swift` if necessary

6. Build and run the project in Xcode

## App Flow

1. **Authentication**: Sign in with Google or Apple
2. **Onboarding**: Import existing contacts (optional)
3. **Subscription**: Choose a subscription plan or restore purchases
4. **Main Interface**: Add contacts, search, and execute commands using natural language

## Project Structure

```
NoteAI/
├── App/
│   ├── NoteAIApp.swift
│   └── ContentView.swift
├── Models/
│   └── Contact.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── SubscriptionViewModel.swift
│   ├── ContactsViewModel.swift
│   └── OnboardingViewModel.swift
├── Services/
│   ├── AuthService.swift
│   ├── DatabaseService.swift
│   ├── ContactsService.swift
│   ├── AIService.swift
│   └── StoreKitService.swift
└── Other Resources
```

## Development Roadmap

### Phase 1 - MVP (Current)
- Basic authentication
- AI-powered contact creation
- Smart labeling
- Natural language search

### Phase 2 - Enhanced Features
- Improved contact synchronization
- More sophisticated AI processing
- Advanced search capabilities
- UI refinements

### Phase 3 - Premium Features
- Contact analytics
- Group management
- Enhanced integrations
- Custom AI training

## Security and Privacy

- All AI processing is done server-side through OpenAI
- Contacts permissions are requested only when needed
- Authentication is handled securely through Supabase
- All data is stored in your Supabase database
