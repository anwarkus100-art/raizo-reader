// PDF.js worker setup
if (window['pdfjsLib']) {
    pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.16.105/pdf.worker.min.js';
}

// DOM Elements
const textInput = document.getElementById('text-input');
const fileUpload = document.getElementById('file-upload');
const themeToggle = document.getElementById('theme-toggle');
const fontDecrease = document.getElementById('font-decrease');
const fontIncrease = document.getElementById('font-increase');
const fontSizeVal = document.getElementById('font-size-val');
const langFilter = document.getElementById('lang-filter');
const voiceSelect = document.getElementById('voice-select');
const rateSlider = document.getElementById('rate-slider');
const rateVal = document.getElementById('rate-val');
const pitchSlider = document.getElementById('pitch-slider');
const pitchVal = document.getElementById('pitch-val');
const volSlider = document.getElementById('vol-slider');
const volVal = document.getElementById('vol-val');
const btnPlay = document.getElementById('btn-play');
const btnPause = document.getElementById('btn-pause');
const btnStop = document.getElementById('btn-stop');
const btnCopy = document.getElementById('btn-copy');
const btnDownload = document.getElementById('btn-download');
const btnSave = document.getElementById('btn-save');
const btnClear = document.getElementById('btn-clear');
const wordCount = document.getElementById('word-count');
const charCount = document.getElementById('char-count');
const readTime = document.getElementById('read-time');
const statusBar = document.getElementById('status-bar');
const readingProgress = document.getElementById('reading-progress');

let currentFontSize = 18;
let themes = ['dark-theme', 'light-theme', 'sepia-theme'];
let currentThemeIndex = 0;
let synth = window.speechSynthesis;
let allVoices = [];
let sentenceChunks = [];
let currentChunkIndex = 0;
let isReading = false;

// Load saved text and preferences on startup
window.addEventListener('DOMContentLoaded', () => {
    const savedText = localStorage.getItem('raizo_saved_text');
    if (savedText) {
        textInput.value = savedText;
        updateStats();
    }
    const savedFont = localStorage.getItem('raizo_font_size');
    if (savedFont) {
        currentFontSize = parseInt(savedFont);
        textInput.style.fontSize = currentFontSize + 'px';
        fontSizeVal.textContent = currentFontSize + 'px';
    }
});

// Update Word, Character, and Reading Time
function updateStats() {
    const text = textInput.value.trim();
    const words = text ? text.split(/\s+/).length : 0;
    const chars = textInput.value.length;
    const minutes = Math.ceil(words / 180);
    
    wordCount.textContent = `শব্দ: ${words}`;
    charCount.textContent = `অক্ষর: ${chars}`;
    readTime.textContent = `সময়: ~${minutes} মিনিট`;
    localStorage.setItem('raizo_saved_text', textInput.value);
}

textInput.addEventListener('input', updateStats);

// Theme Switcher
themeToggle.addEventListener('click', () => {
    document.body.classList.remove(themes[currentThemeIndex]);
    currentThemeIndex = (currentThemeIndex + 1) % themes.length;
    document.body.classList.add(themes[currentThemeIndex]);
    
    const labels = ['🌙 ডার্ক', '☀️ লাইট', '📜 সেপিয়া'];
    themeToggle.textContent = labels[currentThemeIndex];
    statusBar.textContent = `থিম পরিবর্তন করা হয়েছে: ${labels[currentThemeIndex]}`;
});

// Font Size Controls
fontIncrease.addEventListener('click', () => {
    if (currentFontSize < 38) {
        currentFontSize += 2;
        textInput.style.fontSize = currentFontSize + 'px';
        fontSizeVal.textContent = currentFontSize + 'px';
        localStorage.setItem('raizo_font_size', currentFontSize);
    }
});

fontDecrease.addEventListener('click', () => {
    if (currentFontSize > 12) {
        currentFontSize -= 2;
        textInput.style.fontSize = currentFontSize + 'px';
        fontSizeVal.textContent = currentFontSize + 'px';
        localStorage.setItem('raizo_font_size', currentFontSize);
    }
});

// Multi-Language Voice Loader & Filter
function loadVoices() {
    allVoices = synth.getVoices();
    filterVoicesByLang();
}

function filterVoicesByLang() {
    const selectedLang = langFilter.value;
    voiceSelect.innerHTML = '';

    const filtered = allVoices.filter(voice => {
        if (selectedLang === 'all') return true;
        return voice.lang.toLowerCase().includes(selectedLang.toLowerCase());
    });

    if (filtered.length === 0) {
        const opt = document.createElement('option');
        opt.value = -1;
        opt.textContent = `ডিফল্ট সিস্টেম ভয়েস (${selectedLang.toUpperCase()})`;
        voiceSelect.appendChild(opt);
        return;
    }

    filtered.forEach((voice) => {
        const realIndex = allVoices.indexOf(voice);
        const option = document.createElement('option');
        option.value = realIndex;
        option.textContent = `${voice.name} (${voice.lang})`;
        voiceSelect.appendChild(option);
    });
}

if (speechSynthesis.onvoiceschanged !== undefined) {
    speechSynthesis.onvoiceschanged = loadVoices;
}
loadVoices();
langFilter.addEventListener('change', filterVoicesByLang);

// Sliders Event Listeners
rateSlider.addEventListener('input', () => { rateVal.textContent = rateSlider.value + 'x'; });
pitchSlider.addEventListener('input', () => { pitchVal.textContent = pitchSlider.value; });
volSlider.addEventListener('input', () => { volVal.textContent = Math.round(volSlider.value * 100) + '%'; });
// File Upload (TXT and PDF Support)
fileUpload.addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    statusBar.textContent = `লোড হচ্ছে: ${file.name}...`;
    readingProgress.style.width = '10%';

    if (file.type === 'text/plain' || file.name.endsWith('.txt')) {
        const reader = new FileReader();
        reader.onload = (event) => {
            textInput.value = event.target.result;
            updateStats();
            readingProgress.style.width = '100%';
            statusBar.textContent = `✅ সফলভাবে লোড হয়েছে: ${file.name}`;
        };
        reader.readAsText(file);
    } else if (file.type === 'application/pdf' || file.name.endsWith('.pdf')) {
        try {
            const arrayBuffer = await file.arrayBuffer();
            const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
            let extractedText = '';

            for (let i = 1; i <= pdf.numPages; i++) {
                statusBar.textContent = `⏳ PDF পড়া হচ্ছে... পৃষ্ঠা ${i} / ${pdf.numPages}`;
                readingProgress.style.width = `${Math.round((i / pdf.numPages) * 100)}%`;
                const page = await pdf.getPage(i);
                const content = await page.getTextContent();
                const pageText = content.items.map(item => item.str).join(' ');
                extractedText += `--- পৃষ্ঠা ${i} ---\n` + pageText + '\n\n';
            }

            textInput.value = extractedText;
            updateStats();
            statusBar.textContent = `✅ PDF সম্পূর্ণ লোড হয়েছে (${pdf.numPages} পৃষ্ঠা): ${file.name}`;
        } catch (error) {
            statusBar.textContent = '❌ PDF ফাইলটি পড়তে সমস্যা হয়েছে।';
            console.error(error);
        }
    } else {
        statusBar.textContent = '⚠️ শুধুমাত্র .txt অথবা .pdf ফাইল নির্বাচন করুন।';
    }
});

// Smart Chunking Text-to-Speech (Supports Long Texts & Multi-Language)
function splitTextIntoChunks(text) {
    return text.match(/[^।.!?]+[।.!?]+|[^।.!?]+$/g) || [text];
}

function speakNextChunk() {
    if (!isReading || currentChunkIndex >= sentenceChunks.length) {
        isReading = false;
        readingProgress.style.width = '100%';
        statusBar.textContent = '✅ সম্পূর্ণ লেখা পড়া শেষ হয়েছে।';
        return;
    }

    const chunkText = sentenceChunks[currentChunkIndex].trim();
    if (!chunkText) {
        currentChunkIndex++;
        speakNextChunk();
        return;
    }

    const utterance = new SpeechSynthesisUtterance(chunkText);
    const selectedVoiceIndex = parseInt(voiceSelect.value);

    if (selectedVoiceIndex >= 0 && allVoices[selectedVoiceIndex]) {
        utterance.voice = allVoices[selectedVoiceIndex];
        utterance.lang = allVoices[selectedVoiceIndex].lang;
    } else {
        const hasBengali = /[\u0980-\u09FF]/.test(chunkText);
        utterance.lang = langFilter.value !== 'all' ? langFilter.value : (hasBengali ? 'bn-BD' : 'en-US');
    }

    utterance.rate = parseFloat(rateSlider.value);
    utterance.pitch = parseFloat(pitchSlider.value);
    utterance.volume = parseFloat(volSlider.value);

    const progressPercent = Math.round(((currentChunkIndex + 1) / sentenceChunks.length) * 100);
    readingProgress.style.width = `${progressPercent}%`;
    statusBar.textContent = `🔊 পড়া হচ্ছে (${progressPercent}%): "${chunkText.substring(0, 45)}..."`;

    utterance.onend = () => {
        if (isReading) {
            currentChunkIndex++;
            speakNextChunk();
        }
    };

    utterance.onerror = () => {
        isReading = false;
        statusBar.textContent = '⚠️ অডিও প্লে করতে সমস্যা হয়েছে বা থামানো হয়েছে।';
    };

    synth.speak(utterance);
}

btnPlay.addEventListener('click', () => {
    if (synth.paused && isReading) {
        synth.resume();
        statusBar.textContent = '▶ পড়া পুনরায় শুরু হয়েছে...';
        return;
    }

    const text = textInput.value.trim();
    if (!text) {
        statusBar.textContent = '⚠️ শোনার জন্য বক্সে কিছু লেখা থাকতে হবে!';
        return;
    }

    synth.cancel();
    sentenceChunks = splitTextIntoChunks(text);
    currentChunkIndex = 0;
    isReading = true;
    speakNextChunk();
});

btnPause.addEventListener('click', () => {
    if (synth.speaking && !synth.paused) {
        synth.pause();
        statusBar.textContent = '⏸ পড়া বিরতি (Pause) দেওয়া হয়েছে।';
    }
});

btnStop.addEventListener('click', () => {
    isReading = false;
    synth.cancel();
    readingProgress.style.width = '0%';
    statusBar.textContent = '⏹ পড়া বন্ধ করা হয়েছে।';
});

// Utility Actions: Copy, Download, Save, Clear
btnCopy.addEventListener('click', () => {
    if (!textInput.value) return;
    navigator.clipboard.writeText(textInput.value);
    statusBar.textContent = '📋 সম্পূর্ণ লেখা কপি করা হয়েছে!';
});

btnDownload.addEventListener('click', () => {
    if (!textInput.value.trim()) {
        statusBar.textContent = '⚠️ ডাউনলোড করার জন্য বক্সে লেখা থাকতে হবে।';
        return;
    }
    const blob = new Blob([textInput.value], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'Raizo_Reader_Document.txt';
    a.click();
    URL.revokeObjectURL(url);
    statusBar.textContent = '📥 টেক্সট ফাইল ডাউনলোড হয়েছে!';
});

btnSave.addEventListener('click', () => {
    localStorage.setItem('raizo_saved_text', textInput.value);
    statusBar.textContent = '💾 আপনার লেখা ব্রাউজারে সেভ করা হয়েছে!';
});

btnClear.addEventListener('click', () => {
    if (confirm('আপনি কি নিশ্চিত যে সব লেখা মুছে ফেলতে চান?')) {
        isReading = false;
        synth.cancel();
        textInput.value = '';
        localStorage.removeItem('raizo_saved_text');
        readingProgress.style.width = '0%';
        updateStats();
        statusBar.textContent = '🗑️ সব লেখা মুছে ফেলা হয়েছে।';
    }
});