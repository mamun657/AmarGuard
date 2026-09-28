# 🛡️ AmarGuard

## AI-Powered Digital Safety Companion

<p align="center">

**UNDERSTAND BEFORE YOU TRUST.**

</p>

<p align="center">

<img src="https://img.shields.io/badge/Flutter-Mobile%20App-02569B?style=for-the-badge&logo=flutter&logoColor=white">
<img src="https://img.shields.io/badge/Dart-Application-0175C2?style=for-the-badge&logo=dart&logoColor=white">
<img src="https://img.shields.io/badge/Firebase-Backend%20Services-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
<img src="https://img.shields.io/badge/AI-Digital%20Safety-F5B51B?style=for-the-badge">
<img src="https://img.shields.io/badge/Platform-Android-34A853?style=for-the-badge&logo=android&logoColor=white">

</p>

---

# 📥 Download App

<p align="center">

<a href="https://github.com/mamun657/AmarGuard/releases/latest">
<img src="https://img.shields.io/badge/Download%20AmarGuard%20APK-2EA44F?style=for-the-badge&logo=android&logoColor=white">
</a>

</p>

**Latest Android APK:** [Download AmarGuard](../../releases/latest)

> Download the APK and install it on an Android device.

---

# 📌 Project Overview

**AmarGuard** is a Bangla-first digital safety companion designed to help users understand potentially risky digital interactions before they respond.

Instead of focusing only on suspicious links or phone numbers, AmarGuard analyzes the **context of an interaction** and identifies signals that may indicate manipulation, fraud, impersonation, or social engineering.

The platform is designed around:

```text
Detect
   ↓
Understand
   ↓
Explain
   ↓
Protect
```

AmarGuard helps users analyze potentially risky:

* Calls
* Messages
* Links
* Screenshots
* Audio interactions

The goal is to transform confusing digital interactions into understandable safety decisions.

---

# 🎯 Problem Statement

Digital fraud does not always start with a suspicious link.

Many risky interactions begin with normal-looking conversations involving:

* Urgent payment requests
* OTP or PIN requests
* Fake account warnings
* Impersonation
* Prize or reward claims
* Fake job offers
* Delivery scams
* Investment requests
* Authority claims
* Threatening language
* Requests for secrecy

Users often struggle to understand whether an interaction is genuinely risky and, more importantly, **why it is risky**.

Common problems include:

* Difficulty recognizing manipulation patterns
* Lack of understandable risk explanations
* Confusion caused by urgency or threats
* Difficulty evaluating suspicious messages
* Difficulty understanding unfamiliar links
* Lack of Bangla-first safety tools
* Uncertainty about what to do next

AmarGuard focuses on the interaction itself rather than only checking a single URL or phone number.

---

# 💡 Purpose

The purpose of AmarGuard is to provide an accessible digital safety layer that helps people:

* Understand suspicious interactions
* Recognize manipulation signals
* Analyze suspicious messages
* Check potentially risky links
* Analyze screenshots
* Analyze user-provided audio
* Understand why an interaction may be risky
* Make safer decisions before responding
* Access digital safety tools in English and বাংলা

The core philosophy is:

```text
Don't just detect the threat.

Understand the interaction.
```

---

# 🚀 Proposed Solution

AmarGuard provides a multimodal digital safety experience where users can bring different types of suspicious content into one platform.

```text
┌─────────────────────────────────────┐
│          AmarGuard App              │
│                                     │
│  Call / Audio                       │
│  Message                            │
│  Screenshot                         │
│  Link                               │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│       Context & Signal Extraction   │
│                                     │
│  Urgency                            │
│  Secrecy                            │
│  Payment Request                    │
│  OTP / PIN                          │
│  Impersonation                      │
│  Authority Claim                    │
│  Prize / Job / Delivery             │
│  Account Threat                     │
│  Suspicious URL                     │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│        Risk Intelligence Layer      │
│                                     │
│  ML Risk Model                      │
│  Explainability                     │
│  Context Analysis                   │
│  Knowledge Retrieval                │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│       Explanation & Guidance        │
│                                     │
│  Risk Signals                       │
│  Why It May Be Risky                │
│  Recommended Next Steps             │
│  Decision Support                   │
└─────────────────────────────────────┘
```

---

# ✨ Main Features

## 🔐 Authentication

AmarGuard provides account-based access for users who want a persistent safety experience.

### Includes

* User registration
* Email/password authentication
* Protected user experience
* User profile
* Persistent preferences
* Firebase authentication

---

## 👤 Guest Mode

Users can access selected safety-analysis workflows without creating an account.

Guest mode is designed for quick situations where a user wants to check suspicious content without maintaining an account history.

---

## 📞 Analyze Call

AmarGuard provides a dedicated workflow for suspicious call-related interactions.

The product architecture focuses on user-provided or consented audio rather than silently recording ordinary cellular calls.

---

## 💬 Check Message

Users can analyze suspicious messages and conversations.

The system can identify contextual signals such as:

* Urgency
* Secrecy
* Payment requests
* OTP/PIN requests
* Account threats
* Impersonation
* Authority claims
* Prize/reward claims
* Job offers
* Delivery claims
* Investment requests

---

## 🔗 Check Link

Users can submit potentially suspicious URLs for safety-oriented analysis.

The goal is to help users understand both the link and the surrounding interaction context.

---

## 📸 Scan Screenshot

Users can provide screenshots of:

* Suspicious conversations
* Payment requests
* Account warnings
* Prize offers
* Job offers
* Delivery messages
* Social-media interactions

The system can extract useful contextual information from the visual content.

---

## 🎙️ Analyze Audio

Users can provide audio for analysis.

The intended workflow is:

```text
Audio
  ↓
Speech-to-Text
  ↓
Bangla / Banglish Normalization
  ↓
Context Extraction
  ↓
Risk Signal Detection
  ↓
Risk Explanation
```

---

## 👨‍👩‍👧 Family Safety

AmarGuard includes a family-safety concept for trusted contacts and family-oriented digital safety support.

The goal is to help users extend digital safety awareness to people they care about.

---

## 🌐 English + বাংলা

AmarGuard is designed as a Bangla-first digital safety experience.

Users can switch between:

```text
English
   ↕
বাংলা
```

The selected language is persisted for future sessions.

---

# 🧠 Core Interaction Intelligence

AmarGuard focuses on **interaction-level risk signals**.

The system can represent structured signals such as:

```text
payment_request
otp_pin
password_request
urgency
secrecy
authority_claim
impersonation
prize_reward
job_offer
account_threat
delivery_claim
investment_request
emergency_claim
unknown_caller
money_amount
suspicious_url
escalation
```

These signals can contribute to an overall interaction-risk assessment.

---

# 📊 Interaction Risk Score

AmarGuard can represent the assessed risk of an interaction using a structured score.

Example:

```text
Interaction Risk Score

        91 / 100
```

The score represents an **interaction risk assessment**.

It should not be interpreted as:

```text
91% probability of fraud
```

The purpose of the score is to support user understanding and decision-making.

---

# 🔍 Explainable AI

AmarGuard is designed around explainability.

Instead of simply showing:

```text
HIGH RISK
```

the system can explain the signals behind the assessment.

Example:

```text
⚠ Urgent payment request

⚠ Requests sensitive information

⚠ Uses authority or threat language

⚠ Attempts to prevent verification
```

The goal is:

```text
Risk Score
     ↓
Why?
     ↓
Which Signals?
     ↓
What Should I Consider?
```

---

# 🤖 AI Architecture

The AmarGuard intelligence pipeline can combine multiple AI components.

```text
User Input
    │
    ├──────── Message
    ├──────── Screenshot
    ├──────── Link
    └──────── Audio
             │
             ▼
       Context Extraction
             │
             ▼
      Structured Risk Signals
             │
             ▼
       ML Risk Assessment
             │
             ▼
         Explainability
             │
             ▼
       Knowledge Retrieval
             │
             ▼
        AI Explanation
             │
             ▼
       Safety Guidance
```

### AI Components

* Speech-to-text
* Bangla/Banglish normalization
* Context extraction
* Structured risk signals
* XGBoost risk modeling
* SHAP explainability
* Retrieval-Augmented Generation
* Knowledge graph / GraphRAG
* LLM-powered explanations

---

# 🕸️ Threat Intelligence

An advanced AmarGuard intelligence layer can connect related threat patterns using a knowledge graph.

```text
Threat Pattern
      ↓
Manipulation Signal
      ↓
Interaction Context
      ↓
Risk Relationship
      ↓
Safety Guidance
```

A Neo4j-based knowledge graph can be used to represent relationships between threat patterns, signals, and safety guidance.

---

# 🏗️ System Architecture

```text
┌─────────────────────────────────────┐
│          Flutter Application        │
│                                     │
│  UI / Navigation                    │
│  Authentication                     │
│  Guest Mode                         │
│  Analysis Workflows                 │
│  English / বাংলা                    │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│       Application Services          │
│                                     │
│  Authentication                     │
│  User Profile                       │
│  Preferences                        │
│  Cloud Data                         │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│          AI Backend Layer           │
│                                     │
│  Speech Processing                  │
│  Context Extraction                 │
│  ML Risk Model                      │
│  Explainability                     │
│  RAG / LLM                          │
└──────────────────┬──────────────────┘
                   │
           ┌───────┴────────┐
           ▼                ▼
┌─────────────────┐ ┌─────────────────┐
│ Knowledge Layer │ │ Model Services  │
│                 │ │                 │
│ RAG / GraphRAG  │ │ XGBoost / SHAP  │
│ ThreatMesh      │ │ Speech / LLM    │
└─────────────────┘ └─────────────────┘
```

---

# 🔄 End-to-End Application Flow

```text
                    User
                     │
                     ▼
                  Onboarding
                     │
                     ▼
              Login / Guest Mode
                     │
                     ▼
                   Dashboard
                     │
         ┌───────────┼───────────┐
         │           │           │
         ▼           ▼           ▼
       Call        Message      Link
         │           │           │
         └───────────┼───────────┘
                     │
               Screenshot / Audio
                     │
                     ▼
              Context Extraction
                     │
                     ▼
              Risk Signal Analysis
                     │
                     ▼
               Risk Assessment
                     │
                     ▼
                Explanation
                     │
                     ▼
               Safety Guidance
                     │
                     ▼
                User Decision
```

---

# 📱 App Screenshots

## Onboarding
<p align="center">
  <img width="30%" alt="AmarGuard Onboarding 1" src="https://github.com/user-attachments/assets/3dc9974e-5e5b-49c4-bda0-bcb83c98aaed" />
  <img width="30%" alt="AmarGuard Onboarding 2" src="https://github.com/user-attachments/assets/97b45f22-d8cb-47cd-bf95-8e927f086e26" />
  <img width="30%" alt="AmarGuard Onboarding 3" src="https://github.com/user-attachments/assets/0d06daff-f729-4507-a1c2-8e3fb02d3391" />
</p>

---

## Authentication

<p align="center">
<img width="336" height="726" alt="image" src="https://github.com/user-attachments/assets/cf40fdbc-1283-4e91-ab13-7f7067755c1c" />
<img width="338" height="696" alt="image" src="https://github.com/user-attachments/assets/dee584bd-b0be-4cf3-b21a-03393f8b07af" />

</p>

---

## Dashboard

<p align="center">
<img width="339" height="729" alt="image" src="https://github.com/user-attachments/assets/2d2ddb6f-d36d-4d43-9a0f-75ade9ead2bb" />
<img width="332" height="705" alt="image" src="https://github.com/user-attachments/assets/7a541bb0-79ec-47bc-9a35-bc89723d2067" />

</p>

---

## Profile & Language

<p align="center">
 <img width="337" height="722" alt="image" src="https://github.com/user-attachments/assets/030de9c2-d955-4183-96dc-6c28130d5cd8" />
<img width="354" height="714" alt="image" src="https://github.com/user-attachments/assets/2e4cd5ab-e7cf-4cd7-ad62-aca86904e793" />

</p>

---

# 🛠️ Technology Stack

## 📱 Frontend

* Flutter
* Dart
* Material UI
* Shared Preferences
* Firebase Authentication
* Cloud Firestore

---

## 🔥 Firebase

Firebase is used for application services including:

* Authentication
* User profiles
* Cloud data
* Persistent preferences
* Future notification workflows

Firebase acts as the application service layer, while AI inference is handled separately.

---

## 🤖 AI & Machine Learning

* Python
* XGBoost
* SHAP
* Scikit-learn
* Speech-to-text
* LLMs
* Retrieval-Augmented Generation
* Knowledge Graph
* GraphRAG

---

## 🗄️ Data & Knowledge

* Firebase / Firestore
* ChromaDB
* Neo4j
* Structured threat-signal data
* Curated digital safety knowledge

---

# 📂 Flutter Project Structure

```text
lib/
│
├── main.dart
├── app.dart
│
├── core/
│   ├── theme/
│   ├── localization/
│   └── services/
│
├── features/
│   ├── onboarding/
│   ├── auth/
│   ├── dashboard/
│   ├── analyze/
│   ├── history/
│   ├── profile/
│   └── family_safety/
│
└── widgets/
```

---

# 🔐 Security & Privacy

AmarGuard is designed with digital safety and user privacy in mind.

Security principles include:

* Firebase authentication
* Protected user data
* Consent-based audio workflows
* Secure configuration
* No hardcoded secrets
* User-controlled analysis
* Minimal collection of sensitive information

> AmarGuard is a decision-support tool. Users should independently verify important claims and should never share OTPs, PINs, passwords, or financial credentials with untrusted parties.

---

# 📡 Connectivity

Cloud-based AI features require an internet connection through:

* Wi-Fi
* Mobile data

If both are unavailable, cloud AI services cannot be reached unless an on-device intelligence layer is available.

Future versions can explore more offline-capable safety workflows.

---

# ⚠️ Call Audio Limitation

Standard Flutter Android applications cannot universally and silently capture ordinary cellular call audio.

Therefore, AmarGuard's audio-analysis architecture focuses on:

* User-provided audio
* Consent-based recordings
* Supported VoIP/in-app audio
* Future Android-supported call-screening integrations

---

# 🧪 Testing & Verification

Important verification areas include:

```text
Application Launch
       ↓
Onboarding
       ↓
Authentication
       ↓
Guest Mode
       ↓
Dashboard
       ↓
Language Switching
       ↓
Profile
       ↓
Analysis Workflows
       ↓
Firebase Connectivity
       ↓
Android APK Installation
```

The Android release APK has been prepared for physical-device installation and GitHub distribution.

---

# 🚀 Getting Started

## 1. Clone Repository

```bash
git clone https://github.com/mamun657/AmarGuard.git
cd AmarGuard
```

---

## 2. Install Dependencies

```bash
flutter pub get
```

---

## 3. Check Flutter Environment

```bash
flutter doctor
```

---

## 4. Check Connected Devices

```bash
flutter devices
```

Or:

```bash
adb devices
```

---

## 5. Run Application

```bash
flutter run
```

For a specific device:

```bash
flutter run -d <device-id>
```

---

# 📦 Build Android APK

```bash
flutter build apk --release
```

The generated APK will normally be available under:

```text
build/app/outputs/flutter-apk/
```

---

# 📥 Install APK with ADB

Connect an Android device and verify:

```bash
adb devices
```

Then:

```bash
adb install path/to/AmarGuard.apk
```

---

# 🧩 Firebase Configuration

Important Firebase configuration files include:

```text
firebase.json
firebase_options.dart
android/app/google-services.json
```

Never commit private credentials, passwords, private keys, or other secrets to the repository.

---

# 🌐 Localization

AmarGuard supports:

```text
English
বাংলা
```

The selected language is persisted and applied throughout the user interface.

---

# 🛣️ Future Roadmap

Potential future development includes:

* Advanced interaction-risk modeling
* Better Bangla/Banglish understanding
* Real-time threat intelligence
* Threat knowledge graph
* GraphRAG reasoning
* Expanded family safety
* Advanced audio analysis
* On-device AI
* Low-bandwidth optimization
* Supported call-screening integrations
* Telco-level safety integrations
* Expanded multilingual support

---

# 🎯 Product Philosophy

AmarGuard follows four core principles:

```text
DETECT
   ↓
UNDERSTAND
   ↓
EXPLAIN
   ↓
PROTECT
```

The objective is not simply to tell users:

> **"This is dangerous."**

The objective is to help users understand:

> **"Why does this interaction feel risky, and what should I consider before responding?"**

---

# 🤝 Team

## BinaryPulse

AmarGuard is developed by **Team BinaryPulse**.

The project focuses on practical AI-powered digital safety tools with particular attention to:

* Bangla-first accessibility
* Explainable risk assessment
* Multimodal interaction analysis
* User decision support
* Responsible AI

---

# 📄 License

This project is currently intended for educational, research, demonstration, and product-development purposes.

Add the project's final license when the licensing decision is finalized.

---

# ⭐ Support the Project

If you find AmarGuard useful:

* ⭐ Star the repository
* 🐛 Report issues
* 💡 Suggest improvements
* 🤝 Contribute to the project

---

<p align="center">

# 🛡️ AmarGuard

### UNDERSTAND BEFORE YOU TRUST.

**Built by BinaryPulse**

</p>

---

# 📁 Screenshot Folder Structure

Your GitHub repository should contain the following structure:

```text
AmarGuard/
│
├── lib/
├── android/
├── assets/
│
├── docs/
│   └── screenshots/
│       ├── onboarding-01.png
│       ├── onboarding-02.png
│       ├── onboarding-03.png
│       ├── login.png
│       ├── signup.png
│       ├── dashboard-en.png
│       ├── dashboard-bn.png
│       ├── profile-en.png
│       ├── language.png
│       └── profile-bn.png
│
├── README.md
├── pubspec.yaml
└── ...
```
