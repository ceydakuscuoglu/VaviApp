# VAVI – AI-Assisted Indoor Navigation System for Visually Impaired Individuals

VAVI is an AI-powered indoor navigation system developed as a senior graduation project to improve independent mobility for visually impaired individuals. The application combines computer vision, artificial intelligence, and accessibility-focused mobile development to provide accurate indoor localization, real-time obstacle detection, and voice-guided navigation.

---

## 📖 Project Overview

Navigating unfamiliar indoor environments is one of the biggest challenges faced by visually impaired individuals. Since GPS performs poorly indoors, VAVI provides an alternative solution by combining visual scene understanding with real-time object detection.

The system enables users to:

- Determine their indoor location using computer vision
- Select destinations through voice commands or a simple interface
- Calculate the shortest navigation path
- Receive step-by-step voice guidance
- Detect surrounding obstacles in real time

The project follows a hybrid architecture consisting of a Flutter mobile application, FastAPI backend services, AI models, and a Microsoft SQL Server database.

---

## ✨ Features

- ♿ Accessibility-first mobile interface
- 🎤 Voice command support
- 🔊 Text-to-speech navigation guidance
- 📍 Vision-based indoor localization using Gemini API
- 🛣️ Shortest path calculation
- 📷 Real-time object detection with YOLO
- 📡 Backend communication through FastAPI
- 🗄️ Indoor graph data management with Microsoft SQL Server

---

## 🏗️ System Architecture

The system consists of the following components:

- **Flutter Mobile Application**
- **FastAPI Backend**
- **Microsoft SQL Server Database**
- **Gemini API** for indoor location estimation
- **YOLO** for real-time object detection
- **Audio Feedback Module**
- **Voice Recognition Module**

---

## 🚀 How It Works

1. The user selects the source and destination using either dropdown menus or voice commands.
2. If requested, the application captures multiple camera frames.
3. The captured images are analyzed by the Gemini API to estimate the user's current location using visual cues such as office signs and room labels.
4. The shortest path is calculated using the indoor graph.
5. Navigation instructions are provided through audio and text.
6. During navigation, YOLO continuously detects surrounding objects and warns the user about nearby obstacles.

---

## 🛠️ Technologies Used

### Mobile
- Flutter
- Dart

### Backend
- FastAPI
- Python

### Artificial Intelligence
- Gemini API
- YOLO

### Database
- Microsoft SQL Server

### Additional Technologies
- Speech-to-Text
- Text-to-Speech
- Computer Vision
- Graph-based Pathfinding

---

## 📂 Project Structure

```text
lib/
├── main.dart
├── models/
├── screens/
├── services/
├── widgets/
└── utils/
```

---

## 📱 Accessibility Features

VAVI was designed with accessibility as the primary objective.

- Voice-controlled destination selection
- Screen reader compatibility
- Text-to-Speech navigation
- Large touch targets
- High-contrast user interface
- Semantic widgets
- Haptic feedback

---

## 🔬 Development Process

During development, several machine learning models were evaluated for indoor localization, including:

- Random Forest
- K-Nearest Neighbors (KNN)
- Support Vector Machine (SVM)
- XGBoost
- Logistic Regression

Although these approaches produced promising results, they did not achieve the desired level of accuracy in real indoor environments. Therefore, the final version of VAVI adopted a vision-based localization approach using the Gemini API.

---

## 📷 Demo

Project Website:

👉 https://berkaykkaraca.github.io/VAVI/

---

## 🚧 Future Improvements

- Multi-building support
- Offline localization
- Improved sensor fusion
- Enhanced object detection performance
- Navigation history
- Personalized voice assistant
- Wearable device integration

---

## 👥 Team

- **Ceyda Kuşçuoğlu**
- **Kıvanç Terzioğlu**
- **Berkay Kaan Karaca**
---
