# VeriTrust Documentation

## 📚 Quick Links

### Getting Started
- [Setup Guide](SETUP_GUIDE.md) - Complete setup instructions
- [Quick Reference](QUICK_REFERENCE.md) - Common commands and troubleshooting
- [Project Context](PROJECT_CONTEXT.md) - Project overview and architecture

### Integration Guides
- [Axiam Integration](AXIAM_INTEGRATION.md) - Facial authentication (Sign Up & Sign In)

### Deployment
- [Production Deployment](deployment/PRODUCTION_DEPLOYMENT.md) - Step-by-step deployment guide
- [Deployment Checklist](deployment/PRODUCTION_DEPLOYMENT_CHECKLIST.md) - Pre-deployment checklist
- [Security Improvements](deployment/SECURITY_IMPROVEMENTS.md) - Security best practices

### Archive
Historical documentation and migration guides stored in [`archive/`](archive/) folder.

## 📖 Documentation Structure

```
docs/
├── README.md (this file)
├── AXIAM_INTEGRATION.md          # Main Axiam guide
├── PROJECT_CONTEXT.md             # Project overview
├── SETUP_GUIDE.md                 # Setup instructions
├── QUICK_REFERENCE.md             # Quick reference
├── deployment/                    # Deployment docs
│   ├── PRODUCTION_DEPLOYMENT.md
│   ├── PRODUCTION_DEPLOYMENT_CHECKLIST.md
│   └── SECURITY_IMPROVEMENTS.md
└── archive/                       # Historical docs
    ├── AXIAM_SECURITY_RECOMMENDATIONS.md
    ├── AXIAM_WIDGET_*.md
    ├── AUTH_CSS_REFACTORING.md
    └── ... (other migration guides)
```

## 🚀 Quick Start

1. **First time setup**: Read [SETUP_GUIDE.md](SETUP_GUIDE.md)
2. **Axiam integration**: Read [AXIAM_INTEGRATION.md](AXIAM_INTEGRATION.md)
3. **Deploying to production**: Read [deployment/PRODUCTION_DEPLOYMENT.md](deployment/PRODUCTION_DEPLOYMENT.md)
4. **Troubleshooting**: Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

## 💡 Key Features

### ✅ Implemented
- **Sign Up with Face** - Passwordless registration via facial recognition
- **Sign In with Face** - Passwordless login via facial recognition
- **Email Verification** - Secure email verification flow for signup
- **Real-time Updates** - WebSocket notifications via ActionCable
- **Avatar Management** - Automatic facial image download and storage
- **Responsive Design** - Purple gradient UI with shared CSS system

### 🔐 Security Features
- Redis credentials NOT exposed to browser
- CSRF protection enabled
- Secure token generation
- HTTPS/TLS for all API calls
- Session-based authentication

## 📞 Support

- **Axiam API Issues**: Contact Axiam support team
- **VeriTrust Issues**: Check logs in `/var/www/app/log/production.log`
- **Documentation Issues**: Update relevant .md files in `docs/`

## 🔄 Keeping Docs Updated

When making changes:
1. Update relevant documentation
2. Keep archive folder for historical reference
3. Update this README if adding new docs
4. Use clear, concise language
