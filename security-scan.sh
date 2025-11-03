#!/usr/bin/env bash

###############################################################################
# 🔐 Script d'analyse de sécurité complète
# Usage: ./security-scan.sh
###############################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPORTS_DIR="./reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_LOG_ENABLED=false
OUTPUT_LOG_FILE="output.txt"

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
# Vérification de la configuration
###############################################################################

check_configuration() {
    print_header "🔍 Vérification de la Configuration"
    
    local has_error=0
    
    # Charger les variables d'environnement
    if [ ! -f .env ]; then
        print_error "Fichier .env non trouvé"
        print_info "Copiez .env.example vers .env et configurez les valeurs"
        exit 1
    fi
    
    export $(grep -v '^#' .env | xargs 2>/dev/null || true)
    print_success "Fichier .env chargé"
    
    # Vérifier PROJECT_DIR
    if [ -z "$PROJECT_DIR" ]; then
        print_error "PROJECT_DIR non défini dans .env"
        has_error=1
    elif [ ! -d "$PROJECT_DIR" ]; then
        print_error "Répertoire PROJECT_DIR introuvable: $PROJECT_DIR"
        has_error=1
    else
        print_success "Répertoire projet trouvé: $PROJECT_DIR"
    fi
    
    # Vérifier DOCKERFILE
    if [ -n "$DOCKERFILE" ]; then
        local dockerfile_path="$PROJECT_DIR/$DOCKERFILE"
        if [ ! -f "$dockerfile_path" ]; then
            print_warning "Dockerfile introuvable: $dockerfile_path"
            print_info "Le scan Hadolint sera ignoré"
        else
            print_success "Dockerfile trouvé: $dockerfile_path"
        fi
    else
        print_warning "DOCKERFILE non défini dans .env"
        print_info "Le scan Hadolint sera ignoré"
    fi
    
    # Vérifier TARGET_URL
    if [ -z "$TARGET_URL" ]; then
        print_warning "TARGET_URL non défini dans .env"
        print_info "Les scans DAST seront ignorés"
    else
        print_info "Test de connectivité vers $TARGET_URL..."
        local domain=$(echo "$TARGET_URL" | sed -E 's|^https?://||' | sed 's|/.*||')
        if ping -c 1 -W 2 "$domain" &>/dev/null || curl -s --head --max-time 5 "$TARGET_URL" &>/dev/null; then
            print_success "Target URL accessible: $TARGET_URL"
        else
            print_warning "Target URL non accessible: $TARGET_URL"
            print_info "Les scans DAST pourraient échouer"
        fi
    fi
    
    # Vérifier DOCKER_IMAGE
    if [ -z "$DOCKER_IMAGE" ]; then
        print_warning "DOCKER_IMAGE non défini dans .env"
        print_info "Les scans d'images Docker seront ignorés"
    else
        print_info "Vérification de l'image Docker: $DOCKER_IMAGE"
        
        # Extraire registry, image et tag
        local registry=""
        local image_name="$DOCKER_IMAGE"
        
        if [[ "$DOCKER_IMAGE" == *"/"*"/"* ]]; then
            registry=$(echo "$DOCKER_IMAGE" | cut -d'/' -f1)
            image_name=$(echo "$DOCKER_IMAGE" | cut -d'/' -f2-)
        fi
        
        # Vérifier si l'image existe localement
        if docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
            print_success "Image Docker trouvée localement: $DOCKER_IMAGE"
        else
            print_warning "Image Docker non trouvée localement: $DOCKER_IMAGE"
            
            # Vérifier si on peut se connecter au registry
            if [ -n "$registry" ]; then
                print_info "Tentative de connexion au registry: $registry"
                if docker login "$registry" --username=test --password=test &>/dev/null 2>&1; then
                    print_warning "Registry accessible mais credentials requis: $registry"
                    print_info "Lancez: docker login $registry"
                else
                    print_info "Assurez-vous d'être connecté au registry: docker login $registry"
                fi
            fi
            
            print_info "Les scans d'images Docker nécessiteront le téléchargement de l'image"
        fi
    fi
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé"
        has_error=1
    else
        print_success "Docker disponible ($(docker --version))"
    fi
    
    # Vérifier docker compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose n'est pas disponible"
        has_error=1
    else
        print_success "Docker Compose disponible"
    fi
    
    if [ $has_error -eq 1 ]; then
        print_error "Erreurs de configuration détectées. Corrigez-les avant de continuer."
        exit 1
    fi
    
    echo ""
    print_success "Configuration validée ✓"
    echo ""
}

###############################################################################
# Menu interactif
###############################################################################

show_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║       🔐 Suite d'Analyse de Sécurité Complète            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BLUE}Projet:${NC} $PROJECT_DIR"
    echo -e "${BLUE}Target:${NC} ${TARGET_URL:-Non défini}"
    echo -e "${BLUE}Image:${NC}  ${DOCKER_IMAGE:-Non définie}"
    echo ""
    
    # Afficher l'état de l'enregistrement des logs
    if [ "$OUTPUT_LOG_ENABLED" = true ]; then
        echo -e "${BLUE}Enregistrement logs:${NC} ${GREEN}✓ Activé${NC} (fichier: $OUTPUT_LOG_FILE)"
    else
        echo -e "${BLUE}Enregistrement logs:${NC} ${YELLOW}✗ Désactivé${NC}"
    fi
    echo ""
    
    echo "Choisissez le type de scan :"
    echo ""
    echo -e "${GREEN}1)${NC} Scan Rapide (Quick)      - ~15-30 min"
    echo "   Analyse code, dépendances, secrets, conteneurs, TLS/en-têtes"
    echo ""
    echo -e "${GREEN}2)${NC} Scan Complet (Full)      - ~2-4 heures"
    echo "   Quick + Tests dynamiques web (ZAP Full) + Scan réseau (Nmap)"
    echo ""
    echo -e "${GREEN}3)${NC} Analyse du Code Source   - ~5-10 min"
    echo "   Semgrep, PHPStan, PHP-CS-Fixer"
    echo ""
    echo -e "${GREEN}4)${NC} Analyse des Dépendances  - ~10-15 min"
    echo "   Dependency Check, Snyk, Security Checker"
    echo ""
    echo -e "${GREEN}5)${NC} Tests Dynamiques Web     - ~30 min - 1h"
    echo "   ZAP Baseline, Nuclei"
    echo ""
    echo -e "${GREEN}6)${NC} Scan Conteneurs Docker   - ~5-10 min"
    echo "   Trivy, Grype, Hadolint"
    echo ""
    echo -e "${GREEN}7)${NC} Détection Secrets        - ~2-5 min"
    echo "   GitLeaks, TruffleHog"
    echo ""
    echo -e "${GREEN}8)${NC} Vérifier Configuration"
    echo ""
    echo -e "${GREEN}9)${NC} Nettoyer les rapports"
    echo ""
    echo -e "${CYAN}L)${NC} Basculer enregistrement logs (actuellement: $([ "$OUTPUT_LOG_ENABLED" = true ] && echo "activé" || echo "désactivé"))"
    echo ""
    echo -e "${RED}0)${NC} Quitter"
    echo ""
    echo -n "Votre choix : "
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
    rm reports/testssl/testssl-report.html
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
    # Vérifier la configuration au démarrage
    check_configuration
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                print_header "🚀 Lancement du Scan Rapide (Quick)"
                print_info "Durée estimée: 15-30 minutes"
                if [ "$OUTPUT_LOG_ENABLED" = true ]; then
                    print_info "Logs enregistrés dans: $OUTPUT_LOG_FILE"
                    {
                        prepare_environment
                        run_sast
                        run_sca
                        run_container_scan
                        run_secrets_scan
                        run_dast
                        run_tls_headers
                        run_api_tests
                        generate_report
                        cleanup
                    } 2>&1 | tee -a "$OUTPUT_LOG_FILE"
                else
                    prepare_environment
                    run_sast
                    run_sca
                    run_container_scan
                    run_secrets_scan
                    run_dast
                    run_tls_headers
                    run_api_tests
                    generate_report
                    cleanup
                fi
                print_success "✅ Scan rapide terminé!"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            2)
                print_header "🚀 Lancement du Scan Complet (Full)"
                print_warning "Durée estimée: 2-4 heures"
                if [ "$OUTPUT_LOG_ENABLED" = true ]; then
                    print_info "Logs enregistrés dans: $OUTPUT_LOG_FILE"
                    {
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
                    } 2>&1 | tee -a "$OUTPUT_LOG_FILE"
                else
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
                fi
                print_success "✅ Scan complet terminé!"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            3)
                print_header "🧠 Lancement Analyse du Code Source"
                if [ "$OUTPUT_LOG_ENABLED" = true ]; then
                    print_info "Logs enregistrés dans: $OUTPUT_LOG_FILE"
                    {
                        prepare_environment
                        run_sast
                    } 2>&1 | tee -a "$OUTPUT_LOG_FILE"
                else
                    prepare_environment
                    run_sast
                fi
                print_success "✅ Analyse du code source terminée!"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            4)
                print_header "📦 Lancement Analyse des Dépendances"
                if [ "$OUTPUT_LOG_ENABLED" = true ]; then
                    print_info "Logs enregistrés dans: $OUTPUT_LOG_FILE"
                    {
                        prepare_environment
                        run_sca
                    } 2>&1 | tee -a "$OUTPUT_LOG_FILE"
                else
                    prepare_environment
                    run_sca
                fi
                print_success "✅ Analyse des dépendances terminée!"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            5)
                print_header "🌐 Lancement Tests Dynamiques Web"
                if [ "$OUTPUT_LOG_ENABLED" = true ]; then
                    print_info "Logs enregistrés dans: $OUTPUT_LOG_FILE"
                    {
                        prepare_environment
                        run_dast
                        run_tls_headers
                    } 2>&1 | tee -a "$OUTPUT_LOG_FILE"
                else
                    prepare_environment
                    run_dast
                    run_tls_headers
                fi
                print_success "✅ Tests dynamiques web terminés!"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            6)
                print_header "🐳 Lancement Scan Conteneurs Docker"
                if [ "$OUTPUT_LOG_ENABLED" = true ]; then
                    print_info "Logs enregistrés dans: $OUTPUT_LOG_FILE"
                    {
                        prepare_environment
                        run_container_scan
                    } 2>&1 | tee -a "$OUTPUT_LOG_FILE"
                else
                    prepare_environment
                    run_container_scan
                fi
                print_success "✅ Scan conteneurs Docker terminé!"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            7)
                print_header "🔑 Lancement Détection Secrets"
                if [ "$OUTPUT_LOG_ENABLED" = true ]; then
                    print_info "Logs enregistrés dans: $OUTPUT_LOG_FILE"
                    {
                        prepare_environment
                        run_secrets_scan
                    } 2>&1 | tee -a "$OUTPUT_LOG_FILE"
                else
                    prepare_environment
                    run_secrets_scan
                fi
                print_success "✅ Détection secrets terminée!"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            8)
                check_configuration
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            9)
                cleanup
                print_info "Suppression des volumes..."
                docker compose down -v 2>/dev/null || true
                print_success "✅ Nettoyage complet terminé!"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
                ;;
            [Ll])
                if [ "$OUTPUT_LOG_ENABLED" = true ]; then
                    OUTPUT_LOG_ENABLED=false
                    print_info "Enregistrement des logs désactivé"
                else
                    OUTPUT_LOG_ENABLED=true
                    print_success "Enregistrement des logs activé → $OUTPUT_LOG_FILE"
                fi
                sleep 2
                ;;
            0)
                print_info "Au revoir!"
                exit 0
                ;;
            *)
                print_error "Choix invalide"
                sleep 2
                ;;
        esac
    done
}

# Trap pour le nettoyage en cas d'interruption
trap cleanup INT TERM

# Lancement
main

