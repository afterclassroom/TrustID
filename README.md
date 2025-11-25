# VeriTrust - Content Verification Platform

VeriTrust is a content verification platform powered by AI detection and blockchain-based Digital Identity (DID). Integrated with Axiam Facial Sign-On for passwordless authentication.

---

## 🚀 Quick Start

### 1. Setup Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your credentials
nano .env
```

### 2. Start Development Server

```bash
# Using Docker
docker-compose up -d

# Access application
http://localhost:3030
```

### 3. Configure Axiam Integration

See detailed setup guide: **[docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)**

See integration guide: **[docs/AXIAM_INTEGRATION.md](docs/AXIAM_INTEGRATION.md)**

---

## 📚 Documentation

Complete documentation available in **[`docs/`](docs/)** folder:

| Document | Description |
|----------|-------------|
| [Setup Guide](docs/SETUP_GUIDE.md) | Complete setup guide for development & production |
| [Axiam Integration](docs/AXIAM_INTEGRATION.md) | Facial authentication implementation guide |
| [Project Context](docs/PROJECT_CONTEXT.md) | Architecture overview and tech decisions |
| [Quick Reference](docs/QUICK_REFERENCE.md) | Common commands and troubleshooting |
| [Deployment Guides](docs/deployment/) | Production deployment and security |
| [Archive](docs/archive/) | Historical implementation notes |

---

## 🛠️ Tech Stack

- **Ruby:** 3.2.2
- **Rails:** 7.1.6
- **Database:** MySQL 8.1
- **Cache:** Redis 7
- **Frontend:** Tailwind CSS v4, jQuery, Bootstrap 5
- **Authentication:** Devise + Axiam Facial Sign-On
- **Containerization:** Docker

---

## 🔑 Environment Configuration

### Development (Docker localhost:3030)

```bash
AXIAM_API_BASE=http://localhost:3000
AXIAM_DOMAIN=localhost
AXIAM_CABLE_URL=ws://localhost:3000/cable
```

### Production (veritrustai.net)

```bash
AXIAM_API_BASE=https://axiam.io/api
AXIAM_DOMAIN=veritrustai.net
AXIAM_CABLE_URL=wss://axiam.io/cable
```

**Note:** Request credentials from Axiam support (support@axiam.io)

---

## 🧪 Testing

```bash
# Rails console
docker exec -it trustid-web-1 rails console

# Test Axiam authentication
AxiamApi.authenticated_token

# Test client lookup
AxiamApi.lookup_client(email: 'test@example.com')
```

---

## 🐳 Docker Services

| Service | Port | Container |
|---------|------|-----------|
| VeriTrust Web | 3030 | trustid-web-1 |
| Axiam API | 3000 | axiamai_rails-app-1 |
| VeriTrust MySQL | 3308 | trustid-mysql-1 |
| Axiam MySQL | 3307 | axiamai_rails-mysql-1 |
| Redis | 6379 | redis |

---

## 🔒 Security

- ✅ Never commit `.env` to Git
- ✅ Use HTTPS/WSS in production
- ✅ Rotate credentials every 6-12 months
- ✅ Keep dependencies updated

---

## 📞 Support

**Axiam Integration:**
- Email: support@axiam.io
- Technical: developers@axiam.io

**VeriTrust Application:**
- Check logs: `docker-compose logs -f trustid-web-1`
- See documentation: **[`docs/`](docs/)**

---

## 📝 License

Proprietary - All rights reserved

