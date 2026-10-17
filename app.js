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
const voiceSelect = document.getElementById('voice-select');
const rateSlider = document.getElementById('rate-slider');
const rateVal = document.getElementById('rate-val');
const btnPlay = document.getElementById('btn-play');
const btnPause = document.getElementById('btn-pause');
const btnStop = document.getElementById('btn-stop');
const btnSave = document.getElementById('btn-save');
const btnClear = document.getElementById('btn-clear');
const wordCount = document.getElementById('word-count');
const charCount = document.getElementById('char-count');
const statusBar = document.getElementById('status-bar');

let currentFontSize = 18;
let themes = ['dark-theme', 'light-theme', 'sepia-theme'];
let currentThemeIndex = 0;
let synth = window.speechSynthesis;
let voices = [];

// Load saved data on startup
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

// Update Word and Character Count
function updateStats() {
    const text = textInput.value.trim();
    const words = text ? text.split(/\s+/).length : 0;
    const chars = textInput.value.length;
    wordCount.textContent = `শব্দ: ${words}`;
    charCount.textContent = `অক্ষর: ${chars}`;
}

textInput.addEventListener('input', updateStats);

// Theme Switcher (Dark -> Light -> Sepia)
themeToggle.addEventListener('click', () => {
    document.body.classList.remove(themes[currentThemeIndex]);
    currentThemeIndex = (currentThemeIndex + 1) % themes.length;
    document.body.classList.add(themes[currentThemeIndex]);
    
    const icons = ['🌙', '☀️', '📜'];
    themeToggle.textContent = icons[currentThemeIndex];
    statusBar.textContent = `থিম পরিবর্তন করা হয়েছে।`;
});

// Font Size Controls
fontIncrease.addEventListener('click', () => {
    if (currentFontSize < 36) {
        currentFontSize += 2;
        textInput.style.fontSize = currentFontSize + 'px';
        fontSizeVal.textContent = currentFontSize + 'px';
        localStorage.setItem('raizo_font_size', currentFontSize);
    }
});
// File Upload (TXT and PDF Support)
fileUpload.addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    statusBar.textContent = `লোড হচ্ছে: ${file.name}...`;

    if (file.type === 'text/plain' || file.name.endsWith('.txt')) {
        const reader = new FileReader();
        reader.onload = (event) => {
            textInput.value = event.target.result;
            updateStats();
            statusBar.textContent = `সফলভাবে লোড হয়েছে: ${file.name}`;
        };
        reader.readAsText(file);
    } else if (file.type === 'application/pdf' || file.name.endsWith('.pdf')) {
        try {
            const arrayBuffer = await file.arrayBuffer();
            const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
            let extractedText = '';

            for (let i = 1; i <= pdf.numPages; i++) {
                statusBar.textContent = `PDF পড়া হচ্ছে... পৃষ্ঠা ${i} / ${pdf.numPages}`;
                const page = await pdf.getPage(i);
                const content = await page.getTextContent();
                const pageText = content.items.map(item => item.str).join(' ');
                extractedText += `--- পৃষ্ঠা ${i} ---\n` + pageText + '\n\n';
            }

            textInput.value = extractedText;
            updateStats();
            statusBar.textContent = `PDF সম্পূর্ণ লোড হয়েছে (${pdf.numPages} পৃষ্ঠা): ${file.name}`;
        } catch (error) {
            statusBar.textContent = 'PDF ফাইলটি পড়তে সমস্যা হয়েছে।';
            console.error(error);
        }
    } else {
        statusBar.textContent = 'দয়া করে শুধুমাত্র .txt অথবা .pdf ফাইল নির্বাচন করুন।';
    }
});

// Text-to-Speech (TTS) Setup
function loadVoices() {
    voices = synth.getVoices();
    voiceSelect.innerHTML = '';
    voices.forEach((voice, index) => {
        const option = document.createElement('option');
        option.value = index;
        option.textContent = `${voice.name} (${voice.lang})`;
        voiceSelect.appendChild(option);
    });
}

if (speechSynthesis.onvoiceschanged !== undefined) {
    speechSynthesis.onvoiceschanged = loadVoices;
}
loadVoices();

rateSlider.addEventListener('input', () => {
    rateVal.textContent = rateSlider.value + 'x';
});

btnPlay.addEventListener('click', () => {
    if (synth.paused) {
        synth.resume();
        statusBar.textContent = 'পড়া পুনরায় শুরু হয়েছে...';
        return;
    }
    if (synth.speaking) {
        synth.cancel();
    }
    const text = textInput.value.trim();
    if (!text) {
        statusBar.textContent = 'শোনার জন্য বক্সে কিছু লেখা থাকতে হবে!';
        return;
    }

    const utterance = new SpeechSynthesisUtterance(text);
    const selectedVoiceIndex = voiceSelect.value;
    if (voices[selectedVoiceIndex]) {
        utterance.voice = voices[selectedVoiceIndex];
    }
    utterance.rate = parseFloat(rateSlider.value);

    utterance.onstart = () => { statusBar.textContent = '🔊 পড়ে শোনানো হচ্ছে...'; };
    utterance.onend = () => { statusBar.textContent = 'পড়া শেষ হয়েছে।'; };
    utterance.onerror = () => { statusBar.textContent = 'অডিও প্লে করতে সমস্যা হয়েছে।'; };

    synth.speak(utterance);
});

btnPause.addEventListener('click', () => {
    if (synth.speaking && !synth.paused) {
        synth.pause();
        statusBar.textContent = '⏸ পড়া বিরতি (Pause) দেওয়া হয়েছে।';
    }
});

btnStop.addEventListener('click', () => {
    if (synth.speaking) {
        synth.cancel();
        statusBar.textContent = '⏹ পড়া বন্ধ করা হয়েছে।';
    }
});

// Save & Clear Buttons
btnSave.addEventListener('click', () => {
    localStorage.setItem('raizo_saved_text', textInput.value);
    statusBar.textContent = '💾 আপনার লেখা ব্রাউজারে সেভ করা হয়েছে!';
});

btnClear.addEventListener('click', () => {
    if (confirm('আপনি কি নিশ্চিত যে সব লেখা মুছে ফেলতে চান?')) {
        textInput.value = '';
        localStorage.removeItem('raizo_saved_text');
        synth.cancel();
        updateStats();
        statusBar.textContent = '🗑️ সব লেখা মুছে ফেলা হয়েছে।';
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