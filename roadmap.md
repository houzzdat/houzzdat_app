# 🚀 SiteVoice Master Roadmap: MVP to Enterprise Scale

This document serves as the "Source of Truth" for SiteVoice. It ensures that current development sprints align with the long-term goal of building a voice-first, high-integrity System of Record for construction sites.

---

## 🏗️ Phase 1: The Intelligence MVP (Month 1)
**Objective:** Validate the voice-to-structured-data pipeline with 20–30 core users.

- [ ] **1.1 The Validation Gate**
  - **Requirement:** Review screen post-recording.
  - **Logic:** Only the note creator can edit the AI summary before final submission.
  - **Data:** Save final text to `transcript_final` and set `is_edited: true` if modified.
- [ ] **1.2 Actionable Inbox**
  - **Requirement:** Priority-coded feed (Red/Orange/Green) based on AI classification.
  - **Logic:** Contextual buttons (Approve/Delegate/Acknowledge) based on detected intent.
- [ ] **1.3 Proof-of-Work (PoW) Gate**
  - **Requirement:** Mandatory photo capture to move a task to 'Verifying'.
  - **Logic:** Disable "Mark as Done" until a camera-captured photo is uploaded.

---

## 🔄 Phase 2: Operational Rhythm (Month 2)
**Objective:** Transition from individual tasks to a project-wide daily cycle.

- [ ] **2.1 Tiered Orchestration**
  - **Requirement:** Automatic routing based on department (Procurement, Safety, etc.).
  - **Logic:** Sub-orchestrators manage specific teams via the `reports_to` user hierarchy.
- [ ] **2.2 End-of-Day (EOD) Sync**
  - **Requirement:** Scheduled prompts for shift-wrap-up notes.
  - **Logic:** Groq-generated "Daily Pulse" digest summarizing project-wide progress and blockers.
- [ ] **2.3 Dependency Mapping**
  - **Requirement:** Linked task states (Task B depends on Task A).
  - **Logic:** Task B remains locked in the UI until the Manager verifies the PoW for Task A.

---

## 🧠 Phase 3: Project Intelligence (Month 3)
**Objective:** Transform the database into a searchable, actionable intellectual asset.

- [ ] **3.1 Natural Language Querying**
  - **Requirement:** Groq-powered global search bar for historical data.
  - **Example:** "What was the rebar shortage status at HSR Site last Tuesday?"
- [ ] **3.2 Verified Archival**
  - **Requirement:** Split-screen verification for Orchestrators.
  - **Logic:** Side-by-side comparison of "Original Problem" vs. "Resolution Photo."

---

## 📱 Phase 4: Native Frictionless (Months 4–6)
**Objective:** Leverage Android/iOS hardware to eliminate field friction.

- [ ] **4.1 Sensory Field UX**
  - **Requirement:** Raise-to-Record (Proximity Sensor) and Haptic Signatures.
- [ ] **4.2 Safety SOS Override**
  - **Requirement:** Upward-swipe gesture for immediate emergency broadcasting.
- [ ] **4.3 Synchronous Interpretation**
  - **Requirement:** Live Speech-to-Speech (S2S) translation for site meetings.

---

## 🛠️ Technical Guardrails
- **Zero-Inference Data:** Never overwrite `transcript_raw`; always store user edits in `transcript_final`.
- **State Machine:** Status must flow: `pending` -> `in_progress` -> `verifying` (PoW) -> `completed` (Verified).
- **Architecture:** Keep UI Atoms in `core/widgets/shared_widgets.dart` to maintain design consistency.