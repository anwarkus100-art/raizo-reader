# 📖 Rizo Reader

**Rizo Reader** is a feature-rich, multi-language E-Book and PDF reader built with Flutter. It combines a seamless reading experience (PDF & EPUB viewer) with a powerful Background Text-to-Speech (TTS) audio player, allowing you to listen to your favorite books even when your phone screen is turned off.

---

## ✨ Key Features

* **Multi-Format Support:** Open and read PDFs, EPUBs, TXTs, FB2s, and HTML files effortlessly.
* **Background Audio Playback:** Listen to your books with the screen turned off. Fully integrated with Android `Foreground Service` and `WakeLock` to prevent the system from killing playback.
* **Lock-Screen & Notification Controls:** Manage your reading (Play, Pause, Next, Previous) directly from the lock-screen or notification panel like a music player.
* **Dual Modes (Viewer vs. Audio):** Easily toggle between a full-featured visual PDF/EPUB reader and the Text-to-Speech audio mode on the fly.
* **Smart Audio Reading:** Text is split into short, natural sentences for smooth speech, the current line is highlighted and auto-scrolled, and you can tap any line to start from there.
* **Multi-Language Support (12 Languages):** Supports top global languages including **Bengali (বাংলা), Arabic (العربية) with RTL support, English, Hindi (हिन्दी), Urdu (اردو), Mandarin (中文), Spanish, French, Russian, Portuguese, Indonesian, and Japanese**. Your chosen language and reading speed are remembered.
* **Smart Resume (Local Storage):** Automatically remembers your last read page and audio line using `SharedPreferences`. No login or internet required!
* **Continue Reading Dashboard:** Quick access to recently opened books with page tracking, a "Start from beginning" option, and "Remove from list".
* **Modern Dark UI:** Clean navy theme with rounded cards and colour-coded file types (light theme also included).

---

## 🛠️ Tech Stack & Dependencies

* **Framework:** Flutter (Dart)
* **PDF Engine:** `syncfusion_flutter_pdf` & `syncfusion_flutter_pdfviewer`
* **EPUB / HTML Parsing:** `epubx` & `html`
* **Text-to-Speech:** `flutter_tts`
* **Background Audio:** `audio_service`
* **Local Persistence:** `shared_preferences` & `path_provider`
* **Audio Auto-Scroll:** `scrollable_positioned_list`
* **Wake Management:** `wakelock_plus`

---

## 🚀 Build

Every push to `main` / `master` builds a release APK with GitHub Actions. Download it from **Actions → latest run → Artifacts → Rizo-Reader-APK**.

---

## 👨‍💻 Developer & Support

* **Free tool by:** A&R Solution BD
* **Contact Email:** [anwar.kus@gmail.com](mailto:anwar.kus@gmail.com)

---

## 📄 License

This project is open-source and available for personal use.
