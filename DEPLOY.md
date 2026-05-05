# دليل النشر — Hostinger VPS

دليل خطوة بخطوة لنشر RASAD على VPS من Hostinger مع دومين خاص و SSL.

> **نصيحة:** اختر VPS بـ **4 GB RAM فأكثر** و **40 GB SSD**. الـ AI models تستهلك حوالي 1.3 GB ذاكرة بعد التحميل + transformers + Redis.

---

## 0. متطلبات قبل البدء

| | المتطلب | كيف تحصل عليه |
|---|---------|----------------|
| ☑ | حساب Hostinger مع VPS plan | https://www.hostinger.com/vps-hosting |
| ☑ | دومين (مثلاً `rassad.io`) | من Hostinger أو أي مسجّل |
| ☑ | مفاتيح API (اختيارية) | راجع `README.md` → Environment Variables |
| ☑ | `git` و `ssh` على جهازك المحلي | عادة موجودين |

---

## 1. إعداد VPS من Hostinger

### 1.1 إنشاء VPS
1. افتح **hPanel → VPS** → "Order New VPS"
2. اختر:
   - **OS:** Ubuntu 22.04 LTS
   - **Plan:** KVM 2 على الأقل (4 GB RAM, 2 vCPU, 80 GB)
   - **Datacenter:** الأقرب لجمهورك (مثلاً Frankfurt للشرق الأوسط)
3. عيّن **root password** قوي
4. انتظر دقيقتين حتى يُنشأ الـ VPS

### 1.2 الاتصال SSH
```bash
ssh root@<VPS_IP_من_hPanel>
# أدخل الباسوورد
```

### 1.3 تحديث + إعداد المستخدم
```bash
apt update && apt upgrade -y
adduser rasad
usermod -aG sudo rasad
rsync --archive --chown=rasad:rasad ~/.ssh /home/rasad
su - rasad
```

---

## 2. تثبيت Docker + Docker Compose

```bash
# تثبيت Docker الرسمي
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker

# Docker Compose plugin (مدمج في Docker الحديث)
docker compose version
```

---

## 3. سحب المشروع

```bash
cd ~
git clone https://github.com/aboodhaymouni/rasad-platform.git
cd rasad-platform
```

---

## 4. إعداد المتغيّرات

```bash
# Backend
cp backend/.env.example backend/.env
nano backend/.env
```

ضع المفاتيح:
```bash
GEMINI_API_KEY=AIzaSy...                     # من Google AI Studio
HF_API_TOKEN=hf_...                          # من HuggingFace
TAVILY_API_KEY=tvly-...                      # من tavily.com
SERPER_API_KEY=...                           # من serper.dev
BRAVE_API_KEY=                               # اختياري
HIVE_API_KEY=                                # اختياري

REDIS_URL=redis://redis:6379
ENVIRONMENT=production
LOG_LEVEL=INFO

# مهم: استبدل بدومينك الحقيقي
CORS_ORIGINS=https://rassad.io,https://www.rassad.io
```

```bash
# Frontend
cp .env.example .env
nano .env
```

```bash
# مهم: API URL يجب أن يطابق دومينك (سيمر عبر nginx)
VITE_RASAD_API_URL=https://rassad.io/api/v1

# Supabase (لو تستخدمها)
VITE_SUPABASE_URL=https://...
VITE_SUPABASE_PUBLISHABLE_KEY=...
```

---

## 5. تشغيل بـ Docker Compose

```bash
docker compose up -d --build
```

سيستغرق أول build حوالي 5–10 دقائق (تنزيل packages + بناء صور).

### تحقّق:
```bash
docker compose ps                           # كل الخدمات Up
curl http://localhost:8000/api/v1/health    # 200 OK
curl http://localhost:8080                  # HTML للـ frontend
```

---

## 6. إعداد nginx reverse proxy

ركّب nginx على الـ host (خارج Docker) ليتعامل مع SSL والدومين:

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
```

أنشئ ملف `/etc/nginx/sites-available/rassad`:

```nginx
server {
    listen 80;
    server_name rassad.io www.rassad.io;

    # Frontend (Vite static via Docker container :8080)
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend (FastAPI via Docker container :8000)
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90s;
        proxy_connect_timeout 30s;
    }

    client_max_body_size 15M;       # للسماح برفع صور حتى 12 MB
}
```

فعّل الموقع:
```bash
sudo ln -s /etc/nginx/sites-available/rassad /etc/nginx/sites-enabled/
sudo nginx -t                                  # syntax check
sudo systemctl reload nginx
```

---

## 7. توجيه الدومين

في **hPanel → Domains → DNS Zone Editor**، أضف:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | `<VPS_IP>` | 3600 |
| A | www | `<VPS_IP>` | 3600 |

انتظر 5–60 دقيقة حتى تنتشر DNS. تحقق:
```bash
dig +short rassad.io
# يجب أن يُرجع IP الـ VPS
```

---

## 8. SSL مجاني عبر Let's Encrypt

```bash
sudo certbot --nginx -d rassad.io -d www.rassad.io
```

اتبع التعليمات (إيميلك + الموافقة على الشروط). certbot يُحدّث nginx config تلقائياً ويُجدّد الشهادة كل 60 يوم.

تحقق:
```bash
curl -I https://rassad.io
# يجب أن يكون 200 OK مع HTTPS
```

---

## 9. Auto-restart عند الـ reboot

```bash
# Docker Compose يُعيد التشغيل تلقائياً (restart: unless-stopped في الـ compose file)
sudo systemctl enable docker
sudo systemctl enable nginx
```

---

## 10. مراقبة + log files

```bash
# لوقات Backend
docker compose logs -f backend

# لوقات Frontend
docker compose logs -f frontend

# Redis stats
docker compose exec redis redis-cli info stats

# مساحة القرص (راقب hf_cache)
docker system df
du -sh ~/rasad-platform/backend/hf_cache 2>/dev/null
```

---

## 🔄 تحديث المشروع لاحقاً

```bash
cd ~/rasad-platform
git pull
docker compose down
docker compose up -d --build
```

---

## 🧯 Troubleshooting

| مشكلة | الحل |
|-------|------|
| `502 Bad Gateway` من nginx | `docker compose ps` — تأكد أن backend & frontend `Up` |
| Backend يأخذ وقتاً عند البدء (~30s) | طبيعي — تنزيل الموديلات أول مرة. logs يبيّن التقدّم |
| RAM ممتلئة | كبّر VPS لـ 8GB، أو أوقف live monitor: `RASAD_LIVE_MONITOR=0` في `.env` |
| `CORS error` في المتصفح | تحقق `CORS_ORIGINS` في `backend/.env` يحوي دومينك بالـ HTTPS |
| Gemini يقع على template | تحقق `GEMINI_API_KEY` صالح + ليس Free Tier محدود |

---

## 💰 التكلفة التقريبية (شهرياً)

| البند | التكلفة |
|------|---------|
| Hostinger VPS KVM 2 (4 GB RAM) | ~$8 |
| دومين `.io` | ~$3 (متوسط سنوي) |
| Gemini 2.5 Flash (1500 طلب/يوم) | $0 (Free tier) |
| HuggingFace Inference | $0 (Free tier) |
| Tavily / Brave Search | $0 (Free tiers) |
| Let's Encrypt SSL | $0 |
| **الإجمالي** | **~$11/شهر** |

---

## 🟢 Quick Sanity Check بعد النشر

```bash
# Backend health
curl https://rassad.io/api/v1/health
# expected: {"status":"ok","agents":6,"version":"1.0.0",...}

# E2E verify
curl -X POST https://rassad.io/api/v1/verify/text \
  -H "Content-Type: application/json" \
  -d '{"text":"اختبار للنشر على Hostinger"}'
# expected: FinalVerdict JSON خلال 10–15 ثانية
```

افتح https://rassad.io ولاحظ:
- Hero بـ smooth animations
- LiveTicker يجلب أخبار حقيقية كل 12 ثانية
- زر "تحقّق الآن" → التحقق يعمل بنتائج Gemini

---

## 📞 للدعم

- 📚 توثيق كامل: [README.md](./README.md)
- 🔧 OpenAPI: `https://rassad.io/api/v1/docs`
- 🐛 إذا واجهت مشكلة: افتح Issue على GitHub

---

> **تذكير:** بعد النشر، ضع HTTPS فقط في الـ CORS، احفظ نسخة من `backend/.env` (يحوي مفاتيحك)، ولا ترفع `.env` على GitHub أبداً.
