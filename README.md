# 🔐 Security Suite - Réutilisable

Suite complète d'analyse de sécurité automatisée, configurable pour plusieurs projets.

## 🚀 Quick Start

```bash
# 1. Configuration

cp .env.example .env
nano .env  # Définir PROJECT_DIR, DOCKERFILE_PATH, TARGET_URL, DOCKER_IMAGE
# PROJECT_DIR est le chemin absolu vers le projet à scanner.

# 2. Lancer le menu interactif
./security-scan.sh

# 3. Voir un résumé des rapports
./view-results.sh
```

## 📖 Documentation Complète

**→ Voir [GUIDE.md](GUIDE.md) pour :**
- 🛠️ Liste des 15 outils et leur rôle
- ⚙️ Configuration complète (variables d'environnement)
- 🔄 Réutilisation sur d'autres projets
- 🌐 Tests DAST sans blocage OVH (whitelist IP, rate-limiting)
- 📊 Interprétation des résultats
- 🚨 Actions d'urgence et résolution de problèmes

## 🛠️ Outils Inclus (17)

**SAST** : Semgrep, PHPStan, PHP-CS-Fixer  
**SCA** : OWASP Dependency Check, Snyk, Security Checker  
**Conteneurs** : Trivy, Grype, Hadolint  
**Secrets** : GitLeaks, TruffleHog  
**DAST** : OWASP ZAP, Nuclei (configs OVH-friendly)  
**TLS/Headers** : TestSSL, SecurityHeaders  
**Réseau** : Nmap  
**API** : Newman (Postman)

---

**Documentation complète** : [GUIDE.md](GUIDE.md)
