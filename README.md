# 🧠 Cerebro Frontend

This is the Flutter-based mobile interface for **Cerebro**, an AI-powered AR diagnostic assistant designed for radiologists and healthcare professionals. The app allows users to securely log in and interact with AI-driven diagnostic features powered by the Cerebro backend.

---

## 🚀 Tech Stack

- **Flutter**
- **Dart**
- **Material Design**
- **HTTP Package** – for backend communication
- **Provider** – (if used) for state management

---

## 📁 Project Structure

lib/
├── main.dart # App entry point
├── screens/ # Screens like Login, Signup, Dashboard
├── services/ # Backend interaction logic (e.g., API requests)
├── widgets/ # Reusable UI components
├── models/ # Data models (User, Token, etc.)


---

## 🧪 Features

- Login & Signup with validation
- JWT token handling and local storage
- Voice diagnostic interface (planned)
- Communicates with backend FastAPI service

---

## 📦 Getting Started

### 1. Prerequisites

- Flutter SDK installed
- Android Studio or VS Code
- Emulator or physical device

### 2. Clone the Repo

```bash
git clone https://github.com/farahmasoudd/Cerebro-Frontend.git
cd Cerebro-Frontend

-Install Dependencies
flutter pub get

-Run the App
flutter run

-Backend Integration
Make sure to run the Cerebro-backend locally or on a server.

Update your API URLs in the services/ or constants.dart file accordingly.

