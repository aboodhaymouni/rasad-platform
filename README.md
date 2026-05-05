# RASAD | رصد

<p align="right">
  <strong>منصة عربية للتحقق من الأخبار، مدعومة بستة وكلاء ذكاء اصطناعي</strong><br/>
  <em>Arabic AI fact-checking platform — 6 specialized agents, real-time, free.</em>
</p>

<p align="right">
  <a href="#quick-start"><img src="https://img.shields.io/badge/setup-2_minutes-C8392D?style=flat-square" alt="setup"></a>
  <a href="#architecture"><img src="https://img.shields.io/badge/agents-6-1A8A5A?style=flat-square" alt="agents"></a>
  <a href="#deployment-hostinger"><img src="https://img.shields.io/badge/deploy-Hostinger_VPS-6B9BD4?style=flat-square" alt="deploy"></a>
  <a href="https://www.python.org/"><img src="https://img.shields.io/badge/python-3.11-3776AB?style=flat-square&logo=python&logoColor=white" alt="python"></a>
  <a href="https://reactjs.org/"><img src="https://img.shields.io/badge/react-18-61DAFB?style=flat-square&logo=react&logoColor=black" alt="react"></a>
  <img src="https://img.shields.io/badge/license-Educational-E8A020?style=flat-square" alt="license">
</p>

---

## ما هو RASAD؟

ألصق ادعاءً، رابط مقالة، أو ارفع صورة — يبحث رصد في الإنترنت، يقارن المحتوى مع 10 مصادر عربية موثوقة + بحث ويب حي عبر 6 محركات، ويُرجِع حكماً مع أدلة قابلة للتتبع خلال **10–15 ثانية**.

**بدون تسجيل. بدون بطاقة بنكية. كل الميزات مجانية.**

```
verdict: VERIFIED · FALSE · MISLEADING · AI_GENERATED · MANIPULATED
       · OLD_NEWS · UNVERIFIED · DUPLICATE · HIGH_RISK
confidence: 0..100
arabic_explanation: 3-sentence Gemini-synthesized explanation
agent_breakdown: per-agent scores + evidence + sources
```

> **مشروع مقدَّم لمسابقة جامعة الزيتونة الأردنية — مايو 2026**

---

## ✨ الميزات

| | الميزة | التفاصيل |
|---|------|---------|
| 🤖 | **6 وكلاء ذكاء اصطناعي** | تحليل لغوي عربي، أصالة الوسائط، تدقيق المصادر، كشف التضليل، تتبّع الادعاء، محرّك حكم Gemini |
| 🌐 | **بحث حي على الإنترنت** | 7 محركات: Brave, Tavily, Serper, Bing, DDG, SearXNG, Wikipedia |
| 📰 | **مراقبة مستمرة** | 10 مصادر RSS عربية، يحلّلها backend كل 4 دقائق ويصنّفها |
| 🖼️ | **كشف صور AI** | نموذج Organika/sdxl-detector محلياً + EXIF + Hive (اختياري) |
| ⚡ | **بدون login** | Public verification + history في localStorage + export CSV/JSON |
| 🇯🇴 | **عربي أولاً** | RTL كامل، Noto Kufi Arabic، شروحات بالعربية الفصحى |

---

## 🚀 Quick Start

### 1. Backend (FastAPI + 6 agents)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate              # Windows
# source .venv/bin/activate          # macOS/Linux
pip install -r requirements.txt
cp .env.example .env                 # ضع GEMINI_API_KEY (اختياري)
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

### 2. Frontend (Vite + React)

```bash
npm install
cp .env.example .env                 # VITE_RASAD_API_URL مُعدّ مسبقاً
npm run dev
# → http://localhost:8080
```

أول طلب يأخذ ~30 ثانية (تنزيل HuggingFace models). بعدها 10–15 ثانية لكل verdict.

### 3. Docker Compose (الأبسط)

```bash
docker-compose up --build
# Frontend  → http://localhost:8080
# Backend   → http://localhost:8000
# Redis     → 6379
```

---

## 🏗️ Architecture

```
                  ┌─ Hero — embedded LiveTicker (real RSS feed, 12s polling)
Landing  ◄── /  ─┤
                  └─ #verify-now — embedded PublicVerify widget
Verify   ◄── /verify ───── PublicVerify (text / url / image)
Live     ◄── /live ─────── Real-time monitor + risk filters

                       ↓ HTTP (FastAPI)
            ┌─────────────────────────────────────┐
            │  MainOrchestrator (asyncio.gather)  │
            │   ├─ A1 ArabicNLPAgent              │
            │   ├─ A3 ReferenceCheckerAgent  ◄── RSS + 7-engine search + scrape
            │   ├─ A4 MLFakeNewsAgent             │
            │   ├─ A2 MediaAuthAgent (image only) │
            │   ├─ A5 ClaimTracerAgent            │
            │   └─ A6 VerdictEngine (Gemini)      │
            └─────────────────────────────────────┘
                       ↓
            FinalVerdict + sources + agent_breakdown
```

---

## 🤖 The 6 Agents

| # | Agent | Models / APIs | Job |
|---|-------|---------------|-----|
| **A1** | Arabic NLP | CAMeL-BERT sentiment + manipulation regex | Detect emotional manipulation, classify topic, urgency markers |
| **A2** | Media Authenticity | Hive API → `Organika/sdxl-detector` → EXIF | AI-generated/deepfake/metadata tampering detection |
| **A3** | Reference Checker | sentence-transformers + 10 RSS + 7 search engines | Cross-reference claim vs trusted Arabic sources |
| **A4** | ML Fake News | BERT ensemble + pattern detection | Misinformation probability + linguistic patterns |
| **A5** | Claim Tracer | Origin + propagation timeline + domain credibility | First publisher, spread window, credibility-weighted score |
| **A6** | Verdict Engine | Gemini 2.5 Flash | Weighted score + 3-sentence Arabic explanation |

---

## 🌐 Web Search Stack

Tries providers in priority order — **زيرو keys = still works** via Bing HTML + DuckDuckGo + public SearXNG + Wikipedia.

```
Brave > Tavily > Serper > Bing(HTML) > DuckDuckGo > SearXNG > Wikipedia
```

---

## 📡 API Endpoints

```
GET  /api/v1/health                     خدمة الحالة
POST /api/v1/verify/text     {text}     → FinalVerdict
POST /api/v1/verify/url      {url}      → FinalVerdict (يستخرج المقالة)
POST /api/v1/verify/media    multipart  → FinalVerdict (A2 يعمل)
GET  /api/v1/verify/{id}                → استرجاع حكم محفوظ
GET  /api/v1/search?q=..&comprehensive=&scrape=
GET  /api/v1/live/feed?limit=&since=&risk=
GET  /api/v1/live/stats
POST /api/v1/live/refresh               فرض دورة بحث جديدة الآن
GET  /api/v1/stats                      عدّادات لكل verdict label
```

OpenAPI Swagger UI: `http://localhost:8000/docs`

---

## ⚙️ Environment Variables

### Backend (`backend/.env`)

```bash
# المفتاح الوحيد المُوصى به
GEMINI_API_KEY=                # https://aistudio.google.com/apikey

# اختيارية (تتفعّل تلقائياً عند الإضافة)
HF_API_TOKEN=                  # HuggingFace Inference API
HIVE_API_KEY=                  # كشف صور AI احترافي
BRAVE_API_KEY=                 # 2000 استعلام/شهر
TAVILY_API_KEY=                # 1000 استعلام/شهر
SERPER_API_KEY=                # 2500 مجاناً

# Storage
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
REDIS_URL=redis://localhost:6379

# App
ENVIRONMENT=development
LOG_LEVEL=INFO
RASAD_LIVE_MONITOR=1
LIVE_MONITOR_INTERVAL=240
A2_AI_DETECTOR_MODEL=Organika/sdxl-detector
CORS_ORIGINS=http://localhost:8080
```

### Frontend (`.env`)

```bash
VITE_RASAD_API_URL=http://localhost:8000/api/v1
VITE_SUPABASE_URL=...
VITE_SUPABASE_PUBLISHABLE_KEY=...
```

---

## 🎯 Verdict Labels

| Label | Color | Trigger |
|-------|-------|---------|
| `VERIFIED` | 🟢 verified-green | A3 ≥ 0.85 with ≥2 trusted matches |
| `FALSE` | 🔴 signal-red | A4 ≥ 0.75, no source matches |
| `MISLEADING` | 🟡 amber | weighted 0.55–0.75, partial truth |
| `AI_GENERATED` | 🔵 cyan | A2 detects AI signatures |
| `MANIPULATED` | 🟣 purple | A2 detects metadata tampering |
| `OLD_NEWS` | ⚪ grey | A5 origin > 180 days, A3 matches |
| `UNVERIFIED` | ⚪ white | insufficient evidence |
| `DUPLICATE` | ⚫ dark grey | content hash hit cache |
| `HIGH_RISK` | 🔴 pulsing | A3 ≤ 0.30 + A4 ≥ 0.55 |

---

## 🚢 Deployment — Hostinger {#deployment-hostinger}

> راجع [DEPLOY.md](./DEPLOY.md) للتعليمات الكاملة خطوة بخطوة على Hostinger VPS.

**ملخص:**
1. **Hostinger VPS** (4GB RAM فأكثر — لتحميل الموديلات)
2. SSH للسيرفر، استنسخ هذا المستودع
3. ضع المفاتيح في `backend/.env`
4. `docker-compose up -d --build`
5. اربط دومينك على nginx + Let's Encrypt SSL

**خيارات بديلة:**
- **Frontend وحده** على Hostinger Shared/Cloud (يعمل كـ static site من `dist/`)
- **Backend** على VPS منفصل أو على [Render / Fly.io / Railway](https://render.com)

---

## 🛠️ Tech Stack

**Frontend:** React 18 · TypeScript 5 · Vite 5 · Tailwind CSS · shadcn/ui · Lenis (smooth scroll) · React Router · TanStack Query · Sonner

**Backend:** FastAPI 0.110 · Python 3.11 · PyTorch · Transformers · sentence-transformers · trafilatura · feedparser · httpx · Redis · Pydantic v2

**AI:** Gemini 2.5 Flash · CAMeL-BERT · paraphrase-multilingual-MiniLM-L12-v2 · XSY/albert-fakenews · Organika/sdxl-detector

**Infra:** Docker · nginx · Supabase (auth/DB)

---

## 📦 Project Structure

```
rasad-platform/
├── backend/                   # FastAPI Python
│   ├── main.py                # Entry — endpoints + lifespan
│   ├── orchestrator.py        # 6-agent pipeline
│   ├── agents/                # A1–A6
│   ├── models/                # Pydantic schemas
│   ├── services/              # web_search, web_scraper, live_monitor, redis, RSS, …
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example
├── src/                       # Frontend
│   ├── pages/                 # Index, VerifyPublic, Live, About, …
│   ├── components/rasad/      # PublicVerify, LiveTicker, AgentBreakdown, …
│   ├── lib/                   # rasad-api, verdict-mapping, local-history, export
│   └── ...
├── public/                    # favicon.svg, og-image.svg, sitemap, robots
├── supabase/                  # Auth/DB migrations + utility edge functions
├── Dockerfile                 # Frontend prod (multi-stage → nginx)
├── nginx.conf                 # SPA + caching + security headers
├── docker-compose.yml         # redis + backend + frontend
├── .github/workflows/ci.yml   # tsc + lint + build + Docker
├── DEPLOY.md                  # Hostinger deployment guide
└── README.md
```

---

## 🧪 Open-source Models Used

All run locally on CPU. Cached in `backend/hf_cache/` after first download.

| Model | Size | Used by |
|-------|------|---------|
| `CAMeL-Lab/bert-base-arabic-camelbert-msa-sentiment` | ~440 MB | A1, A4 |
| `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` | ~118 MB | A3 |
| `XSY/albert-base-v2-fakenews-discriminator` | ~50 MB | A4 |
| `Organika/sdxl-detector` | ~600 MB | A2 |

---

## 👥 Team

|   | Role |
|---|------|
| **عبد الرحمن الهيموني** ([@aboodhaymouni](https://github.com/aboodhaymouni)) | Full-stack & UX |
| **عبد الرحمن الكردي** ([@kurdim12](https://github.com/kurdim12)) | AI engineer & agents |
| **زيد أبو الشعر** | Backend & infrastructure |

> Built for **Al-Zaytoonah University Competition · May 2026** 🇯🇴

---

## 📜 License

Built for educational and demonstration purposes. Use the verdict pipeline responsibly — no automated decision should rely solely on it. Always read the `sources[]` array before sharing.

---

<p align="right">
  <a href="#rasad--رصد">⬆ العودة للأعلى</a>
</p>
