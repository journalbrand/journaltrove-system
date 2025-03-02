# Todo App System

This repository is the system-level coordinator for the Todo App ecosystem, defining requirements and structure for:

- Mobile clients (iOS-Swift, Android-Kotlin) 
- IPFS node backend (Go)
- Cryptographic identity management
- Secure data exchange

## 🌹 Repository Structure

The Todo App ecosystem is composed of multiple repositories:

- **[todo-system](https://github.com/journalbrand/todo-system)** - System-level coordination and requirements (this repo)
- **[todo-ios](https://github.com/journalbrand/todo-ios)** - iOS client (Swift)
- **[todo-android](https://github.com/journalbrand/todo-android)** - Android client (Kotlin)
- **[todo-ipfs](https://github.com/journalbrand/todo-ipfs)** - IPFS node implementation (Go)

## 🚀 Getting Started

### Setting Up Your Development Environment

1. Clone all repositories:

```bash
git clone https://github.com/journalbrand/todo-system.git
git clone https://github.com/journalbrand/todo-ios.git
git clone https://github.com/journalbrand/todo-android.git
git clone https://github.com/journalbrand/todo-ipfs.git
```

2. Open the workspace in VSCode:

```bash
code todo-system/todo-app.code-workspace
```

This will open all repositories in a single VSCode window.

## 📋 Requirements Management

This ecosystem uses structured JSON-LD for requirements management and traceability.

### Requirements Structure

- System-level requirements are defined in `todo-system/requirements/requirements.jsonld`
- Component-level requirements are defined in each component repository under `requirements/requirements.jsonld`
- The JSON-LD schema is defined in `todo-system/requirements/context/requirements-context.jsonld`

### Adding New Requirements

1. For system-level requirements, edit `todo-system/requirements/requirements.jsonld`
2. For component-level requirements, edit the requirements file in the component repository
3. Ensure that component requirements reference their parent system requirements

## 🧪 Current Project State

We are currently in the initial requirements definition phase. The following components are in active development:

- ✅ System-level requirements definition
- ✅ JSON-LD requirements schema
- ✅ Multi-repository structure
- ✅ Initial CI/CD validation

As we progress, we will implement:

- Client development (iOS, Android)  
- IPFS node implementation
- Test automation
- Compliance reporting

## 🔄 Current CI/CD Capabilities

Our CI/CD pipeline currently:

1. Validates the structure of our JSON-LD requirements 
2. Ensures that all requirements follow the defined schema

**Note**: We follow a strict "fail fast" approach. CI workflows will explicitly fail if components are incomplete or tests don't pass, rather than showing artificial success with placeholders. 