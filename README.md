# Hackathon Technical Disclosure & Compliance Document

## Team Information
- **Team Name**: CodeBlooded
- **Project Title**: FallAssist
- **Problem Statement / Track**: 
- **Team Members**: Surya Thota, Suhas Choudhary, Sai Veena Borra, Nitheesh Purnanand, and Shreeja Chaudhary
- **Repository Link (if public)**: https://www.github.com/suryaat19/code-ronin-CodeBlooded
- **Deployment Link (if applicable)**:

---
make a dot in square brackets for selection 

## 1. APIs & External Services Used

For **each API / external service**, teams must clearly specify the following:

### API / Service Entry
- **API / Service Name**:
- **Provider / Organization**:
- **Purpose in Project**:
- **API Type**:
  - [ ] REST
  - [ ] GraphQL
  - [ ] SDK
  - [ ] Other (specify)
- **License Type**:
  - [ ] Open Source
  - [ ] Free Tier
  - [ ] Academic
  - [ ] Commercial
- **License Link / Documentation URL**:
- **Rate Limits (if any)**:
- **Commercial Use Allowed**:
  - [ ] Yes
  - [ ] No
  - [ ] Unclear

> Repeat this section for every API or external service used.

---

## 2. API Keys & Credentials Declaration

Teams **must disclose how API keys or credentials are obtained and handled**.

- **API Key Source**:
  - [ ] Self-generated from official provider
  - [ ] Hackathon-provided key
  - [ ] Open / Keyless API
- **Key Storage Method**:
  - [ ] Environment Variables
  - [ ] Secure Vault
  - [ ] Backend-only (not exposed)
- **Hardcoded in Repository**:
  - [ ] Yes 
  - [ ] No 

 **Hardcoding API keys in public repositories will lead to disqualification.**

---

## 3. Open Source Libraries & Frameworks
List **all major libraries, frameworks, and SDKs** used.
| Name | Version | Purpose | License |
|------|--------|--------|--------|
| Flutter | 3.x | Cross-platform app development framework | BSD |
| Dart SDK | >=3.0 | Programming language for Flutter | BSD |
| Provider | ^6.0.0 | State management | MIT |
| sensors_plus | ^6.1.0 | Access accelerometer & gyroscope data | MIT |
| flutter_background_service | ^5.0.0 | Run app in background | MIT |
| flutter_background_service_android | ^6.3.1 | Android background execution | MIT |
| flutter_background_service_ios | ^5.0.3 | iOS background execution | MIT |
| wakelock_plus | ^1.2.0 | Keep device awake during monitoring | MIT |
| flutter_local_notifications | ^17.0.0 | Send alerts and notifications | BSD |
| tflite_flutter | ^0.10.1 | Run ML model on device | Apache 2.0 |
| geolocator | ^9.0.0 | Get user location for emergency | MIT |
| url_launcher | ^6.2.0 | Trigger SMS / calls | BSD |
| flutter_tts | ^4.2.5 | Text-to-speech accessibility | MIT |
| speech_to_text | ^7.0.0 | Voice commands and speech recognition | MIT |
| scikit-learn | 1.x | ML library used for training Logistic Regression model | BSD |


---

## 4. AI Models, Tools & Agents Used
Teams must **explicitly disclose all AI usage**.
### AI Models
- **Model Name**: Logistic Regression
- **Provider**: Scikit-learn (Open Source)
- **Used For**: Fall detection classification using sensor features
- **Access Method**:
- [.] API
- [ ] Local Model
- [ ] Hosted Platform

- **Tool Name**: ChatGPT (GPT-5.3)
- **Role in Project**: Assisted in system design, debugging, and documentation
- **Level of Dependency**:
- [.] Assistive
- [ ] Core Logic
- [ ] Entire Solution
- **Tool Name**: Claude
- **Role in Project**: Code refinement
- **Level of Dependency**:
- [.] Assistive
- [ ] Core Logic
- [ ] Entire Solution
---

## 5. AI Agent Usage Declaration (IMPORTANT)

The following must be declared clearly:

- **AI Agents Used** (if any):
  - [ ] None
  - [.] Yes (list below)

### If Yes:
- **Agent Name / Platform**: Claude
- **Capabilities Used**:
  - [.] Code generation
  - [ ] Full app scaffolding
  - [ ] Decision making
  - [ ] Autonomous workflows
- **Human Intervention Level**:
  - [.] High (manual design & logic)
  - [ ] Medium
  - [ ] Low (mostly autonomous)

---

## 6. Restricted / Discouraged AI Services

To preserve **originality, creativity, and fair competition**, the following restrictions apply:

### Disallowed
- Fully autonomous platforms that:
  - Generate **entire applications end-to-end**
  - Make architectural decisions without human reasoning
  - Auto-generate UI + backend + deployment with minimal input

### Restricted (Must Be Declared & Justified)
Examples include but are not limited to:
- Emergent-style autonomous app builders
- Full-stack auto-generation agents
- Prompt-to-product systems

Usage is allowed **only if**:
- Core logic is human-designed
- AI is used as an **assistant**, not a replacement
- Teams can clearly explain architecture & decisions

Failure to justify usage may impact **innovation and originality scores**.

---

## 7. Originality & Human Contribution Statement

Briefly explain:
- What parts were **designed and implemented by humans**
- What parts were **assisted by AI**
- What makes your solution **unique**

---

## 8. Ethical, Legal & Compliance Checklist

- [.] No copyrighted data used without permission
- [.] No leaked or private datasets
- [.] API usage complies with provider TOS
- [.] No malicious automation or scraping
- [.] No AI-generated plagiarism

---

## 9. Final Declaration

> We confirm that all information provided above is accurate.  
> We understand that misrepresentation may lead to disqualification.

**Team Representative Name**: Surya Thota


---
