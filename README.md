# Talkify Receiver App 📞

Talkify is a high-performance, real-time communication platform built with Flutter. This repository contains the **Receiver App**, designed to handle incoming audio and video calls with low latency and high reliability.

---

##  Key Features
- **Real-time Video/Audio Calling**: Seamless communication powered by Agora SDK.
- **High-Priority Signaling**: Instant call notifications even when the app is in the background or killed.
- **Dynamic Call Management**: Real-time synchronization of call states (Ringing, Accepted, Rejected, Ended).

---

## 🛠 Technical Architecture

### 1. Firebase Integration 
Firebase serves as the backbone of the application for real-time data and infrastructure:
- **Firebase Authentication**: Secure user login and identity management.
- **Cloud Firestore**: Acts as the signaling server, maintaining a `calls` collection to track active sessions, participant data, and call status updates in real-time.
- **Cloud Functions**: Serverless logic that handles complex signaling flows, such as generating call documents and managing event triggers.

### 2. Agora SDK Implementation 🎥
The app leverages the **Agora RTC (Real-Time Communication) SDK** for industry-leading media delivery:
- Supports both **Audio** and **Video** call modes.
- Implements dynamic channel joining based on unique `channelName` identifiers.
- Optimized for low-bandwidth scenarios to ensure crystal-clear communication.

### 3. Webhook & Signaling System ⚓
The call lifecycle is managed through a robust webhook-based signaling architecture:
- **`startCall` Webhook**: Triggered when a caller initiates a session. It creates the necessary Firestore metadata and prepares the signaling payload.
- **`handleCallEvent` Webhook**: Manages state transitions like `accepted`, `rejected`, or `ended`, ensuring both the caller and receiver are perfectly in sync.

### 4. Push Notifications (FCM) 
To ensure 100% reachability, we use **Firebase Cloud Messaging (FCM)**:
- **High-Priority Data Messages**: Custom FCM payloads are sent to wake up the receiver's device.
- **Background Handling**: Integration with background services to trigger the "Incoming Call" screen even if the device is locked or the app is closed.
- **Android Integration**: Utilizes high-importance notification channels for immediate visual and audible alerts.

---



## 📁 Project Structure
- `lib/screens/`: UI implementation including the premium call screens.
- `lib/providers/`: State management for call logic and Agora engine.
- `lib/models/`: Data models for calls and users.

---

