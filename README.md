# 📖 Raizo Reader

**Raizo Reader** is a feature-rich, multi-language E-Book and PDF reader built with Flutter. It combines a seamless reading experience (PDF & EPUB viewer) with a powerful Background Text-to-Speech (TTS) audio player, allowing you to listen to your favorite books even when your phone screen is turned off.

---

## ✨ Key Features

* **Multi-Format Support:** Open and read PDFs, EPUBs, TXTs, FB2s, and HTML files effortlessly.
* **Background Audio Playback:** Listen to your books with the screen turned off. Fully integrated with Android `Foreground Service` and `WakeLock` to prevent the system from killing playback.
* **Lock-Screen & Notification Controls:** Manage your reading (Play, Pause, Next, Previous) directly from the lock-screen or notification panel like a music player.
* **Dual Modes (Viewer vs. Audio):** Easily toggle between a full-featured visual PDF/EPUB reader and the Text-to-Speech audio mode on the fly.
* **Multi-Language Support (12+ Languages):** Supports top global languages including **Bengali (বাংলা), Arabic (العربية) with RTL support, English, Hindi (हिन्दी), Urdu (اردو), Mandarin (中文), Spanish, French, Russian, Portuguese, Indonesian, and Japanese**.
* **Smart Resume (Local Storage):** Automatically remembers your last read page, audio line, and zoom level using `SharedPreferences`. No login or internet required!
* **Continue Reading Dashboard:** Quick access to recently opened books with metadata, page tracking, and a "Start from beginning" option.

---

## 🛠️ Tech Stack & Dependencies

* **Framework:** Flutter (Dart)
* **PDF Engine:** `syncfusion_flutter_pdf` & `syncfusion_flutter_pdfviewer`
* **EPUB Parser:** `epubx` & `xml`
* **Text-to-Speech:** `flutter_tts`
* **Background Audio:** `audio_service`
* **Local Persistence:** `shared_preferences`
* **Wake Management:** `wakelock_plus`

---

## 👨‍💻 Developer & Support

* **Free tool by:** A&R Solution BD
* **Contact Email:** [anwar.kus@gmail.com](mailto:anwar.kus@gmail.com)

---

## 📄 License

This project is open-source and available for personal use.
