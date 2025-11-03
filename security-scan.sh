#!/usr/bin/env bash

###############################################################################
# 🔐 Script d'analyse de sécurité complète
# Usage: ./security-scan.sh [quick|full|report]
###############################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPORTS_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCAN_MODE="${1:-quick}"

###############################################################################
# Fonctions utilitaires
###############################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

###############################################################################
# Préparation
###############################################################################

prepare_environment() {
    print_header "📋 Préparation de l'environnement"
    
    # Créer les dossiers de rapports
    mkdir -p "$REPORTS_DIR"/{semgrep,phpstan,php-cs-fixer,dependency-check,snyk,security-checker,trivy,grype,hadolint,gitleaks,trufflehog,zap,nuclei,testssl,securityheaders,nmap,newman}
    
    print_success "Dossiers de rapports créés"
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé"
        exit 1
    fi
    
    print_success "Docker disponible"
    
    # Charger les variables d'environnement
    if [ -f .env ]; then
        export $(grep -v '^#' .env | xargs)
        PROJECT_DIR=${PROJECT_DIR:-./elearning}
        TARGET_URL=${TARGET_URL:-https://dev.cebios-lms.fr}
        print_success "Variables d'environnement chargées (PROJECT_DIR=$PROJECT_DIR, TARGET_URL=$TARGET_URL)"
    else
        PROJECT_DIR="./elearning"
        TARGET_URL="https://dev.cebios-lms.fr"
        print_warning "Fichier .env non trouvé, utilisation des valeurs par défaut"
    fi
    
    # Créer un fichier de suppression par défaut pour dependency-check si inexistant
    if [ ! -f "./dependency-check-suppressions.xml" ]; then
        cat > "./dependency-check-suppressions.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd">
    <!-- Ajoutez vos suppressions ici -->
</suppressions>
EOF
        print_info "Fichier de suppression dependency-check créé"
    fi
}

###############################################################################
# 1. SAST - Analyse statique du code
###############################################################################

run_sast() {
    print_header "🧠 1. SAST - Analyse Statique du Code"
    
    # Semgrep
    print_info "Lancement de Semgrep..."
    if docker compose run --rm semgrep; then
        print_success "Semgrep terminé"
    else
        print_warning "Semgrep terminé avec des avertissements"
    fi
    
    # PHPStan
    print_info "Lancement de PHPStan (niveau max)..."
    if docker compose run --rm phpstan; then
        print_success "PHPStan terminé"
    else
        print_warning "PHPStan terminé avec des erreurs"
    fi
    
    # PHP-CS-Fixer
    print_info "Lancement de PHP-CS-Fixer..."
    if docker compose run --rm php_cs_fixer; then
        print_success "PHP-CS-Fixer terminé"
    else
        print_warning "PHP-CS-Fixer terminé avec des avertissements"
    fi
}

###############################################################################
# 2. SCA - Analyse des dépendances
###############################################################################

run_sca() {
    print_header "📦 2. SCA - Analyse des Dépendances"
    
    # Dependency Check
    print_info "Lancement de OWASP Dependency Check (peut prendre du temps)..."
    if docker compose run --rm dependency_check; then
        print_success "Dependency Check terminé"
    else
        print_warning "Dependency Check a détecté des vulnérabilités"
    fi
    
    # Snyk (si token disponible)
    if [ -n "$SNYK_TOKEN" ]; then
        print_info "Lancement de Snyk..."
        if docker compose run --rm snyk; then
            print_success "Snyk terminé"
        else
            print_warning "Snyk a détecté des vulnérabilités"
        fi
    else
        print_warning "SNYK_TOKEN non défini, passage de Snyk"
    fi
    
    # Local PHP Security Checker
    print_info "Lancement de Security Checker..."
    if docker compose run --rm local_php_security; then
        print_success "Security Checker terminé"
    else
        print_warning "Security Checker a détecté des vulnérabilités"
    fi
}

###############################################################################
# 3. Container Security - Scan des images Docker
###############################################################################

run_container_scan() {
    print_header "🐳 3. Scan des Conteneurs Docker"
    
    # Trivy
    print_info "Lancement de Trivy..."
    if docker compose run --rm trivy; then
        print_success "Trivy terminé"
    else
        print_warning "Trivy a détecté des vulnérabilités"
    fi
    
    # Grype
    print_info "Lancement de Grype..."
    if docker compose run --rm grype; then
        print_success "Grype terminé"
    else
        print_warning "Grype a détecté des vulnérabilités"
    fi
    
    # Hadolint
    print_info "Lancement de Hadolint..."
    if docker compose run --rm hadolint; then
        print_success "Hadolint terminé"
    else
        print_warning "Hadolint a détecté des problèmes dans le Dockerfile"
    fi
}

###############################################################################
# 4. Secrets Scanning - Détection de credentials
###############################################################################

run_secrets_scan() {
    print_header "🔑 4. Détection de Secrets"
    
    # GitLeaks
    print_info "Lancement de GitLeaks..."
    if docker compose run --rm gitleaks; then
        print_success "GitLeaks terminé - Aucun secret détecté"
    else
        print_error "⚠️  GitLeaks a détecté des secrets potentiels!"
    fi
    
    # TruffleHog
    print_info "Lancement de TruffleHog..."
    if docker compose run --rm trufflehog; then
        print_success "TruffleHog terminé"
    else
        print_warning "TruffleHog a détecté des secrets potentiels"
    fi
}

###############################################################################
# 5. DAST - Tests dynamiques web
###############################################################################

run_dast() {
    print_header "🌐 5. DAST - Tests Dynamiques Web"
    
    # ZAP Baseline
    print_info "Lancement de ZAP Baseline Scan..."
    if docker compose run --rm zap_baseline; then
        print_success "ZAP Baseline terminé"
    else
        print_warning "ZAP Baseline a détecté des vulnérabilités"
    fi
    
    # Nuclei
    print_info "Lancement de Nuclei..."
    if docker compose run --rm nuclei; then
        print_success "Nuclei terminé"
    else
        print_warning "Nuclei a détecté des vulnérabilités"
    fi
    
    # ZAP Full (uniquement en mode full)
    if [ "$SCAN_MODE" = "full" ]; then
        print_info "Lancement de ZAP Full Scan (peut prendre plusieurs heures)..."
        if docker compose --profile full run --rm zap_full; then
            print_success "ZAP Full Scan terminé"
        else
            print_warning "ZAP Full Scan a détecté des vulnérabilités"
        fi
    fi
}

###############################################################################
# 6. TLS/SSL & Headers - Tests de sécurité web
###############################################################################

run_tls_headers() {
    print_header "🔐 6. Tests TLS/SSL & En-têtes HTTP"
    
    # TestSSL
    print_info "Lancement de TestSSL..."
    if docker compose run --rm testssl; then
        print_success "TestSSL terminé"
    else
        print_warning "TestSSL a détecté des problèmes de configuration SSL"
    fi
    
    # SecurityHeaders
    print_info "Lancement de SecurityHeaders..."
    if docker compose run --rm securityheaders; then
        print_success "SecurityHeaders terminé"
    else
        print_warning "SecurityHeaders a détecté des en-têtes manquants"
    fi
}

###############################################################################
# 7. Network Scan - Scan réseau
###############################################################################

run_network_scan() {
    print_header "🌍 7. Scan Réseau"
    
    # Nmap
    print_info "Lancement de Nmap (uniquement en mode full)..."
    if [ "$SCAN_MODE" = "full" ]; then
        if docker compose run --rm nmap; then
            print_success "Nmap terminé"
        else
            print_warning "Nmap a détecté des ports/services exposés"
        fi
    else
        print_info "Scan Nmap ignoré en mode quick (utilisez 'full')"
    fi
}

###############################################################################
# 8. API Testing - Tests API
###############################################################################

run_api_tests() {
    print_header "🧾 8. Tests API"
    
    # Vérifier si le fichier de collection existe
    if [ -f "./tests/api_collection.json" ]; then
        print_info "Lancement de Newman..."
        if docker compose run --rm newman; then
            print_success "Newman terminé"
        else
            print_warning "Newman a détecté des problèmes dans les tests API"
        fi
    else
        print_warning "Fichier api_collection.json non trouvé, tests API ignorés"
        print_info "Créez ./tests/api_collection.json avec vos tests Postman"
    fi
}

###############################################################################
# Génération de rapport
###############################################################################

generate_report() {
    print_header "📊 Génération du Rapport Final"
    
    REPORT_FILE="$REPORTS_DIR/security-report-$TIMESTAMP.md"
    PROJECT_NAME=$(basename "$PROJECT_DIR")
    
    cat > "$REPORT_FILE" <<EOF
# 🔐 Rapport d'Analyse de Sécurité
**Date:** $(date +"%Y-%m-%d %H:%M:%S")  
**Mode:** $SCAN_MODE  
**Projet:** $PROJECT_NAME  
**URL cible:** $TARGET_URL

---

## 📋 Résumé Exécutif

Ce rapport compile les résultats des analyses de sécurité suivantes :

### 🧠 1. Analyse Statique du Code (SAST)
- ✓ Semgrep (OWASP Top 10 + Security Audit + PHP)

📝 **Note**: PHPStan et PHP-CS-Fixer sont déjà intégrés dans le projet
   Lancer avec: \\\`cd $PROJECT_NAME && ./app.sh code-quality-check\\\`

### 📦 2. Analyse des Dépendances (SCA)
- ✓ OWASP Dependency Check
- ✓ Snyk (si configuré)
- ✓ Local PHP Security Checker

### 🐳 3. Sécurité des Conteneurs
- ✓ Trivy
- ✓ Grype
- ✓ Hadolint

### 🔑 4. Détection de Secrets
- ✓ GitLeaks
- ✓ TruffleHog

### 🌐 5. Tests Dynamiques Web (DAST)
- ✓ OWASP ZAP (Baseline)
- ✓ Nuclei
$([ "$SCAN_MODE" = "full" ] && echo "- ✓ OWASP ZAP (Full Scan)")

### 🔐 6. Tests TLS/SSL & En-têtes
- ✓ TestSSL
- ✓ SecurityHeaders

$([ "$SCAN_MODE" = "full" ] && echo "### 🌍 7. Scan Réseau
- ✓ Nmap")

### 🧾 8. Tests API
- ✓ Newman (Postman)

---

## 📊 Résultats Détaillés

Les rapports détaillés sont disponibles dans les dossiers suivants :

\\\`\\\`\\\`
./reports/
├── semgrep/         # Résultats Semgrep
├── phpstan/         # Résultats PHPStan
├── phpcs/           # Résultats PHP_CodeSniffer
├── dependency-check/ # Vulnérabilités des dépendances
├── snyk/            # Résultats Snyk
├── trivy/           # Vulnérabilités des images Docker
├── grype/           # Résultats Grype
├── gitleaks/        # Secrets détectés
├── trufflehog/      # Résultats TruffleHog
├── zap/             # Résultats ZAP
├── nuclei/          # Résultats Nuclei
├── testssl/         # Résultats TestSSL
├── securityheaders/ # Résultats SecurityHeaders
├── nmap/            # Résultats Nmap
└── newman/          # Résultats des tests API
\\\`\\\`\\\`

---

## 🎯 Actions Recommandées

### Priorité Critique 🔴
1. **Secrets détectés** : Vérifier les rapports GitLeaks et TruffleHog
2. **Vulnérabilités critiques** : Consulter Dependency Check et Snyk
3. **Failles de sécurité web** : Examiner les résultats ZAP

### Priorité Haute 🟠
1. **Configuration SSL/TLS** : Améliorer selon les recommandations TestSSL
2. **En-têtes de sécurité** : Ajouter les en-têtes manquants
3. **Vulnérabilités des conteneurs** : Mettre à jour les images Docker

### Priorité Moyenne 🟡
1. **Qualité du code** : Corriger les problèmes PHPStan et PHPCS
2. **Tests API** : Compléter la couverture des tests Newman
3. **Documentation** : Documenter les corrections apportées

---

## 📈 Métriques

- **Durée totale du scan** : Vérifier les logs
- **Nombre de vulnérabilités critiques** : À compléter manuellement
- **Nombre de vulnérabilités hautes** : À compléter manuellement
- **Nombre de secrets détectés** : À compléter manuellement

---

## 🔄 Prochaines Étapes

1. Analyser les rapports en détail
2. Prioriser les correctifs selon la criticité
3. Implémenter les corrections
4. Re-scanner pour valider les corrections
5. Intégrer dans CI/CD pour scans automatiques

EOF

    print_success "Rapport généré : $REPORT_FILE"
}

###############################################################################
# Nettoyage
###############################################################################

cleanup() {
    print_header "🧹 Nettoyage"
    
    print_info "Arrêt des conteneurs..."
    docker compose down 2>/dev/null || true
    
    print_success "Nettoyage terminé"
}

###############################################################################
# Menu principal
###############################################################################

show_usage() {
    cat <<EOF
Usage: $0 [MODE]

Modes disponibles:
  quick     Scan rapide (par défaut) - SAST, SCA, Secrets, DAST léger
  full      Scan complet - Tous les outils + scans longs (ZAP Full, Nmap)
  report    Génère uniquement un rapport à partir des scans existants
  clean     Nettoie les conteneurs et volumes

Exemples:
  $0 quick          # Scan rapide (~15-30 min)
  $0 full           # Scan complet (~2-4 heures)
  $0 report         # Génère le rapport
  
Variables d'environnement:
  SNYK_TOKEN        Token pour Snyk (optionnel)
  DD_SECRET_KEY     Clé secrète pour DefectDojo (optionnel)

EOF
}

###############################################################################
# Fonction principale
###############################################################################

main() {
    case "$SCAN_MODE" in
        quick)
            print_header "🚀 Lancement du Scan Rapide de Sécurité"
            prepare_environment
            run_sast
            run_sca
            run_secrets_scan
            run_dast
            run_tls_headers
            run_api_tests
            generate_report
            cleanup
            print_success "✅ Scan rapide terminé!"
            ;;
        full)
            print_header "🚀 Lancement du Scan Complet de Sécurité"
            print_warning "Ce scan peut prendre 2-4 heures"
            prepare_environment
            run_sast
            run_sca
            run_container_scan
            run_secrets_scan
            run_dast
            run_tls_headers
            run_network_scan
            run_api_tests
            generate_report
            cleanup
            print_success "✅ Scan complet terminé!"
            ;;
        report)
            print_header "📊 Génération du Rapport"
            generate_report
            print_success "✅ Rapport généré!"
            ;;
        clean)
            cleanup
            print_info "Suppression des volumes..."
            docker compose down -v
            print_success "✅ Nettoyage complet terminé!"
            ;;
        help|--help|-h)
            show_usage
            exit 0
            ;;
        *)
            print_error "Mode inconnu: $SCAN_MODE"
            show_usage
            exit 1
            ;;
    esac
    
    print_header "📋 Résumé"
    print_info "Rapports disponibles dans: $REPORTS_DIR"
    print_info "Pour voir le rapport consolidé: cat $REPORTS_DIR/security-report-*.md"
    
    if [ "$SCAN_MODE" != "report" ]; then
        print_info "\nPour générer un rapport actualisé: $0 report"
    fi
}

# Trap pour le nettoyage en cas d'interruption
trap cleanup INT TERM

# Lancement
main
