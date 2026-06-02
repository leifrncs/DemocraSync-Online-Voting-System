# DemocraSync

DemocraSync is an automated, secure, and intuitive online voting platform designed to modernize the student electoral process . It serves as a modern replacement for traditional methods like manual voting or generic Google Forms, eliminating hours of manual document verification and minimizing counting delays or errors . 

The platform manages the entire election lifecycle within a single system—from automated student registration to real-time administrative oversight and instant results .

---

## 🚀 Features

*   **Automated Student Registration:** Integrates an AI OCR service to scan and verify student Certificates of Registration (COR), preventing unauthorized registrations .
*   **Dynamic Student Dashboard:** Allows verified users to view voting guidelines, seamlessly cast their ballots, and manage their profile settings (including email updates and password resets) via a bottom navigation system .
*   **Secure Ballot Review:** Provides a final verification screen before a ballot is submitted to minimize accidental selection errors .
*   **Real-Time Admin Control Center:** Gives election administrators the power to instantly start or close elections from the app bar, configure specific positions and available seats, and securely reset election data .
*   **Live Analytics & Reporting:** Displays real-time vote tallies using graphical charts and allows admins to instantly generate and download official PDF tally reports .

---

## 🛠️ Tech Stack

DemocraSync is powered by a reliable, modern technology stack ensuring cross-platform stability, security, and high performance :

### Frontend
*   **Flutter & Dart:** For delivering a smooth, high-performance, and consistent UI design across both mobile and web environments .

### Backend & Database
*   **Firebase Authentication:** Used to handle secure student and admin user logins.
*   **Cloud Firestore:** Serving as the real-time database to ensure all cast votes are updated and tallied instantly.
*   **Firestore Security Rules:** Implemented to enforce strict role-based data isolation, protecting voter and election integrity from unauthorized tampering.

### External Services & AI
*   **AI OCR (Optical Character Recognition) Service:** Integrated to automatically parse text from uploaded enrollment documents for instant, automated user verification.
