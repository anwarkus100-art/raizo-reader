import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xml/xml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

late EbookAudioHandler _audioHandler;

class SupportedLanguage {
  final String name;
  final String code;
  final List<String> fallbackCodes;
  final String flag;

  const SupportedLanguage({
    required this.name,
    required this.code,
    this.fallbackCodes = const [],
    required this.flag,
  });
}

const List<SupportedLanguage> worldLanguages = [
  SupportedLanguage(
    name: 'বাংলা (Bengali)',
    code: 'bn-BD',
    fallbackCodes: ['bn-IN', 'bn'],
    flag: '🇧🇩',
  ),
  SupportedLanguage(
    name: 'العربية (Arabic)',
    code: 'ar-SA',
    fallbackCodes: ['ar', 'ar-XA', 'ar-EG'],
    flag: '🇸🇦',
  ),
  SupportedLanguage(
    name: 'English (English)',
    code: 'en-US',
    fallbackCodes: ['en-GB', 'en'],
    flag: '🇺🇸',
  ),
  SupportedLanguage(
    name: 'हिन्दी (Hindi)',
    code: 'hi-IN',
    fallbackCodes: ['hi'],
    flag: '🇮🇳',
  ),
  SupportedLanguage(
    name: 'اردو (Urdu)',
    code: 'ur-PK',
    fallbackCodes: ['ur-IN', 'ur'],
    flag: '🇵🇰',
  ),
  SupportedLanguage(
    name: '中文 (Mandarin)',
    code: 'zh-CN',
    fallbackCodes: ['zh-TW', 'zh'],
    flag: '🇨🇳',
  ),
  SupportedLanguage(
    name: 'Español (Spanish)',
    code: 'es-ES',
    fallbackCodes: ['es-MX', 'es'],
    flag: '🇪🇸',
  ),
  SupportedLanguage(
    name: 'Français (French)',
    code: 'fr-FR',
    fallbackCodes: ['fr-CA', 'fr'],
    flag: '🇫🇷',
  ),
  SupportedLanguage(
    name: 'Русский (Russian)',
    code: 'ru-RU',
    fallbackCodes: ['ru'],
    flag: '🇷🇺',
  ),
  SupportedLanguage(
    name: 'Português (Portuguese)',
    code: 'pt-BR',
    fallbackCodes: ['pt'],
    flag: '🇧🇷',
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _audioHandler = await AudioService.init(
    builder: () => EbookAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.raizo.reader.channel.audio',
      androidNotificationChannelName: 'Raizo Reader Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(const RaizoReaderApp());
}

class RaizoReaderApp extends StatelessWidget {
  const RaizoReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Raizo Reader',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const ReaderHomeScreen(),
    );
  }
}

/// স্থায়ী ফুটার উইজেট যা সব স্ক্রিনের নিচে থাকবে
class PermanentFooter extends StatelessWidget {
  const PermanentFooter({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'anwar.kus@gmail.com',
      query: 'subject=Feedback for Raizo Reader',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: isDark ? Colors.grey[900] : Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Free tool by A&R Solution BD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: _launchEmail,
            child: const Text(
              'anwar.kus@gmail.com',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EbookAudioHandler extends BaseAudioHandler with SeekHandler {
  final FlutterTts _tts = FlutterTts();
  List<String> paragraphs = [];
  int currentIndex = 0;
  bool isPlaying = false;
  String currentLang = 'bn-BD';
  double speechRate = 0.5;
  String? bookId;

  final ValueNotifier<int> currentParagraphNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);

  EbookAudioHandler() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(currentLang);
    await _tts.setSpeechRate(speechRate);
    await _tts.awaitSpeakCompletion(true);

    _tts.setCompletionHandler(() {
      if (isPlaying && currentIndex < paragraphs.length - 1) {
        currentIndex++;
        currentParagraphNotifier.value = currentIndex;
        _saveProgress();
        _speakCurrentParagraph();
      } else {
        stop();
      }
    });
  }

  Future<void> _saveProgress() async {
    if (bookId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${bookId}_audio_index', currentIndex);
  }

  void loadBook(String id, String title, List<String> extractedParagraphs, {int startIndex = 0}) {
    stop();
    bookId = id;
    paragraphs = extractedParagraphs;
    currentIndex = startIndex < paragraphs.length ? startIndex : 0;
    currentParagraphNotifier.value = currentIndex;

    mediaItem.add(MediaItem(
      id: title,
      album: 'Raizo Reader',
      title: title,
      artist: 'Line ${currentIndex + 1} / ${paragraphs.length}',
    ));
  }

  Future<bool> setLanguageWithFallbacks(SupportedLanguage lang) async {
    final codesToTry = [lang.code, ...lang.fallbackCodes];
    for (final code in codesToTry) {
      final available = await _tts.isLanguageAvailable(code);
      if (available == true) {
        currentLang = code;
        await _tts.setLanguage(code);
        if (isPlaying) {
          await _tts.stop();
          _speakCurrentParagraph();
        }
        return true;
      }
    }
    return false;
  }

  Future<void> setSpeed(double rate) async {
    speechRate = rate;
    await _tts.setSpeechRate(rate);
  }

  Future<void> jumpToParagraph(int index) async {
    if (index >= 0 && index < paragraphs.length) {
      currentIndex = index;
      currentParagraphNotifier.value = currentIndex;
      _saveProgress();
      if (isPlaying) {
        await _tts.stop();
        _speakCurrentParagraph();
      } else {
        play();
      }
    }
  }

  Future<void> _speakCurrentParagraph() async {
    if (paragraphs.isEmpty || currentIndex >= paragraphs.length) return;
    final currentMedia = mediaItem.value;
    if (currentMedia != null) {
      mediaItem.add(currentMedia.copyWith(
        artist: 'Line ${currentIndex + 1} / ${paragraphs.length}',
      ));
    }
    await _tts.speak(paragraphs[currentIndex]);
  }

  @override
  Future<void> play() async {
    if (paragraphs.isEmpty) return;
    isPlaying = true;
    playingNotifier.value = true;
    WakelockPlus.enable();

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      playing: true,
      processingState: AudioProcessingState.ready,
    ));

    await _speakCurrentParagraph();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    playingNotifier.value = false;
    await _tts.stop();
    _saveProgress();

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      playing: false,
      processingState: AudioProcessingState.ready,
    ));
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    playingNotifier.value = false;
    WakelockPlus.disable();
    await _tts.stop();
    _saveProgress();

    playbackState.add(playbackState.value.copyWith(
      controls: [],
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> skipToNext() async {
    if (currentIndex < paragraphs.length - 1) {
      await jumpToParagraph(currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (currentIndex > 0) {
      await jumpToParagraph(currentIndex - 1);
    }
  }
}

class ReaderHomeScreen extends StatefulWidget {
  const ReaderHomeScreen({super.key});

  @override
  State<ReaderHomeScreen> createState() => _ReaderHomeScreenState();
}

class _ReaderHomeScreenState extends State<ReaderHomeScreen> {
  List<Map<String, dynamic>> recentBooks = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentBooks();
  }

  Future<void> _loadRecentBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    List<Map<String, dynamic>> loadedBooks = [];

    for (String key in keys) {
      if (key.endsWith('_meta')) {
        final dataStr = prefs.getString(key);
        if (dataStr != null) {
          try {
            final data = jsonDecode(dataStr) as Map<String, dynamic>;
            loadedBooks.add(data);
          } catch (_) {}
        }
      }
    }

    setState(() {
      recentBooks = loadedBooks;
    });
  }

  Future<void> _openFileAndParse({String? existingId, bool startFromBeginning = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub', 'txt', 'fb2', 'html'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final ext = result.files.single.extension?.toLowerCase() ?? '';
    final name = result.files.single.name;
    final size = await file.length();
    final bookId = existingId ?? '${name}_$size';

    setState(() => isLoading = true);

    try {
      String rawText = '';
      if (ext == 'pdf') {
        final bytes = await file.readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        rawText = PdfTextExtractor(document).extractText();
        document.dispose();
      } else if (ext == 'epub') {
        final bytes = await file.readAsBytes();
        final epubBook = await EpubReader.readBook(bytes);
        final buffer = StringBuffer();
        for (var chapter in epubBook.Chapters ?? []) {
          if (chapter.HtmlContent != null) {
            final doc = XmlDocument.parse(chapter.HtmlContent!);
            buffer.writeln(doc.innerText);
          }
        }
        rawText = buffer.toString();
      } else {
        rawText = await file.readAsString(encoding: utf8);
      }

      final paragraphs = rawText
          .split(RegExp(r'\n+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final prefs = await SharedPreferences.getInstance();
      int savedPage = startFromBeginning ? 0 : (prefs.getInt('${bookId}_page') ?? 0);
      int savedAudioIndex = startFromBeginning ? 0 : (prefs.getInt('${bookId}_audio_index') ?? 0);

      // Save metadata
      final meta = {
        'id': bookId,
        'title': name,
        'path': file.path,
        'ext': ext,
        'lastPage': savedPage,
      };
      await prefs.setString('${bookId}_meta', jsonEncode(meta));

      if (!startFromBeginning && prefs.getInt('${bookId}_page') == null) {
        await prefs.setInt('${bookId}_page', 0);
      }

      setState(() => isLoading = false);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingScreen(
            bookId: bookId,
            bookTitle: name,
            filePath: file.path,
            fileExtension: ext,
            paragraphs: paragraphs,
            initialPage: savedPage,
            initialAudioIndex: savedAudioIndex,
          ),
        ),
      ).then((_) => _loadRecentBooks());
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raizo Reader'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _openFileAndParse(),
                          icon: const Icon(Icons.add),
                          label: const Text('Open New PDF / EPUB / eBook'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Continue Reading',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: recentBooks.isEmpty
                              ? const Center(
                                  child: Text('No books opened yet. Open a book to start!'),
                                )
                              : ListView.builder(
                                  itemCount: recentBooks.length,
                                  itemBuilder: (context, index) {
                                    final book = recentBooks[index];
                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(Icons.book, color: Colors.deepPurple),
                                        title: Text(book['title'] ?? 'Unknown Book'),
                                        subtitle: Text('Last Page: ${book['lastPage'] ?? 0}'),
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'continue') {
                                              _openFileAndParse(existingId: book['id']);
                                            } else if (value == 'restart') {
                                              _openFileAndParse(existingId: book['id'], startFromBeginning: true);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'continue',
                                              child: Text('Continue Reading'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'restart',
                                              child: Text('Start from beginning'),
                                            ),
                                          ],
                                        ),
                                        onTap: () => _openFileAndParse(existingId: book['id']),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
          const PermanentFooter(),
        ],
      ),
    );
  }
}

class ReadingScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String filePath;
  final String fileExtension;
  final List<String> paragraphs;
  final int initialPage;
  final int initialAudioIndex;

  const ReadingScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.filePath,
    required this.fileExtension,
    required this.paragraphs,
    required this.initialPage,
    required this.initialAudioIndex,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  bool isAudioMode = false;
  SupportedLanguage selectedLanguage = worldLanguages.first;
  double speed = 0.5;
  late PdfViewerController _pdfViewerController;
  final ScrollController _audioScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _audioHandler.loadBook(widget.bookId, widget.bookTitle, widget.paragraphs, startIndex: widget.initialAudioIndex);
  }

  Future<void> _saveCurrentPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${widget.bookId}_page', page);
    
    // Update metadata json
    final metaStr = prefs.getString('${widget.bookId}_meta');
    if (metaStr != null) {
      try {
        final meta = jsonDecode(metaStr) as Map<String, dynamic>;
        meta['lastPage'] = page;
        await prefs.setString('${widget.bookId}_meta', jsonEncode(meta));
      } catch (_) {}
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select Reading Language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: worldLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = worldLanguages[index];
                    return ListTile(
                      leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
                      title: Text(lang.name),
                      onTap: () async {
                        Navigator.pop(context);
                        final success = await _audioHandler.setLanguageWithFallbacks(lang);
                        if (success) {
                          setState(() => selectedLanguage = lang);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isRtl = selectedLanguage.code.startsWith('ar') || selectedLanguage.code.startsWith('ur');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: Text(selectedLanguage.flag, style: const Text
