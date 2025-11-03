#!/usr/bin/env bash

###############################################################################
# 📊 Script de visualisation rapide des résultats de sécurité
# Usage: ./view-results.sh
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPORTS_DIR="./reports"

###############################################################################
# Fonctions utilitaires
###############################################################################

print_header() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} $(printf "%-58s" "$1") ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
    echo -e "${BLUE}$(printf '%.0s─' {1..60})${NC}"
}

count_json_findings() {
    local file=$1
    local key=${2:-"results"}
    
    if [ -f "$file" ]; then
        jq ".$key | length" "$file" 2>/dev/null || echo "N/A"
    else
        echo "N/A"
    fi
}

###############################################################################
# Vérification
###############################################################################

if [ ! -d "$REPORTS_DIR" ]; then
    echo -e "${RED}❌ Dossier reports/ non trouvé${NC}"
    echo -e "${YELLOW}Lancez d'abord: ./security-scan.sh quick${NC}"
    exit 1
fi

print_header "🔐 RÉSUMÉ DES ANALYSES DE SÉCURITÉ"

###############################################################################
# 1. SAST
###############################################################################

print_section "🧠 1. SAST - Analyse Statique du Code"

# Semgrep
if [ -f "$REPORTS_DIR/semgrep/semgrep-report.json" ]; then
    findings=$(jq '.results | length' "$REPORTS_DIR/semgrep/semgrep-report.json" 2>/dev/null || echo "0")
    critical=$(jq '[.results[] | select(.extra.severity == "ERROR")] | length' "$REPORTS_DIR/semgrep/semgrep-report.json" 2>/dev/null || echo "0")
    
    echo -e "  ${CYAN}Semgrep:${NC}"
    echo -e "    Total findings: ${YELLOW}$findings${NC}"
    echo -e "    Critical: ${RED}$critical${NC}"
    
    if [ "$findings" -gt 0 ]; then
        echo -e "    Fichier: ${BLUE}$REPORTS_DIR/semgrep/semgrep-report.json${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ Semgrep: Pas de rapport${NC}"
fi

# PHPStan
if [ -f "$REPORTS_DIR/phpstan/phpstan-report.json" ]; then
    errors=$(jq '.totals.errors // 0' "$REPORTS_DIR/phpstan/phpstan-report.json" 2>/dev/null || echo "0")
    file_errors=$(jq '.totals.file_errors // 0' "$REPORTS_DIR/phpstan/phpstan-report.json" 2>/dev/null || echo "0")
    
    echo -e "\n  ${CYAN}PHPStan:${NC}"
    echo -e "    Erreurs: ${RED}$errors${NC}"
    echo -e "    Fichiers avec erreurs: ${YELLOW}$file_errors${NC}"
    
    if [ "$errors" -gt 0 ]; then
        echo -e "    Fichier: ${BLUE}$REPORTS_DIR/phpstan/phpstan-report.json${NC}"
    fi
else
    echo -e "\n  ${YELLOW}⚠ PHPStan: Pas de rapport${NC}"
fi

# PHP-CS-Fixer
if [ -f "$REPORTS_DIR/php-cs-fixer/php-cs-fixer-report.json" ]; then
    issues=$(jq '.files | length' "$REPORTS_DIR/php-cs-fixer/php-cs-fixer-report.json" 2>/dev/null || echo "0")
    
    echo -e "\n  ${CYAN}PHP-CS-Fixer:${NC}"
    echo -e "    Fichiers avec problèmes de style: ${YELLOW}$issues${NC}"
    
    if [ "$issues" -gt 0 ]; then
        echo -e "    Fichier: ${BLUE}$REPORTS_DIR/php-cs-fixer/php-cs-fixer-report.json${NC}"
    fi
else
    echo -e "\n  ${YELLOW}⚠ PHP-CS-Fixer: Pas de rapport${NC}"
fi

###############################################################################
# 2. SCA
###############################################################################

print_section "📦 2. SCA - Analyse des Dépendances"

# Dependency Check
if [ -f "$REPORTS_DIR/dependency-check/dependency-check-report.json" ]; then
    total=$(jq '.dependencies | length' "$REPORTS_DIR/dependency-check/dependency-check-report.json" 2>/dev/null || echo "0")
    critical=$(jq '[.dependencies[].vulnerabilities[]? | select(.severity == "CRITICAL")] | length' "$REPORTS_DIR/dependency-check/dependency-check-report.json" 2>/dev/null || echo "0")
    high=$(jq '[.dependencies[].vulnerabilities[]? | select(.severity == "HIGH")] | length' "$REPORTS_DIR/dependency-check/dependency-check-report.json" 2>/dev/null || echo "0")
    
    echo -e "  ${CYAN}OWASP Dependency Check:${NC}"
    echo -e "    Dépendances analysées: ${BLUE}$total${NC}"
    echo -e "    Vulnérabilités CRITICAL: ${RED}$critical${NC}"
    echo -e "    Vulnérabilités HIGH: ${YELLOW}$high${NC}"
    
    if [ "$critical" -gt 0 ] || [ "$high" -gt 0 ]; then
        echo -e "    ${RED}⚠️  ACTION REQUISE${NC}"
        echo -e "    Voir: ${BLUE}$REPORTS_DIR/dependency-check/dependency-check-report.html${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ Dependency Check: Pas de rapport${NC}"
fi

# Snyk
if [ -f "$REPORTS_DIR/snyk/snyk-report.json" ]; then
    vulns=$(jq '.vulnerabilities | length' "$REPORTS_DIR/snyk/snyk-report.json" 2>/dev/null || echo "0")
    echo -e "\n  ${CYAN}Snyk:${NC}"
    echo -e "    Vulnérabilités: ${YELLOW}$vulns${NC}"
else
    echo -e "\n  ${YELLOW}⚠ Snyk: Pas de rapport (token configuré ?)${NC}"
fi

###############################################################################
# 3. Secrets
###############################################################################

print_section "🔑 3. Détection de Secrets"

# GitLeaks
if [ -f "$REPORTS_DIR/gitleaks/gitleaks-report.json" ]; then
    secrets=$(jq 'length' "$REPORTS_DIR/gitleaks/gitleaks-report.json" 2>/dev/null || echo "0")
    
    echo -e "  ${CYAN}GitLeaks:${NC}"
    if [ "$secrets" -gt 0 ]; then
        echo -e "    ${RED}⚠️  SECRETS DÉTECTÉS: $secrets${NC}"
        echo -e "    ${RED}🚨 ACTION IMMÉDIATE REQUISE !${NC}"
        echo -e "    Voir: ${BLUE}$REPORTS_DIR/gitleaks/gitleaks-report.json${NC}"
        
        # Afficher les premiers secrets détectés
        echo -e "\n    Détails:"
        jq -r '.[] | "      - \(.RuleID): \(.File):\(.StartLine)"' "$REPORTS_DIR/gitleaks/gitleaks-report.json" 2>/dev/null | head -n 5
    else
        echo -e "    ${GREEN}✓ Aucun secret détecté${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ GitLeaks: Pas de rapport${NC}"
fi

# TruffleHog
if [ -f "$REPORTS_DIR/trufflehog/trufflehog-report.json" ]; then
    secrets=$(wc -l < "$REPORTS_DIR/trufflehog/trufflehog-report.json" | tr -d ' ')
    echo -e "\n  ${CYAN}TruffleHog:${NC}"
    echo -e "    Détections: ${YELLOW}$secrets${NC}"
else
    echo -e "\n  ${YELLOW}⚠ TruffleHog: Pas de rapport${NC}"
fi

###############################################################################
# 4. Containers
###############################################################################

print_section "🐳 4. Sécurité des Conteneurs"

# Trivy
if [ -f "$REPORTS_DIR/trivy/trivy-report.json" ]; then
    critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$REPORTS_DIR/trivy/trivy-report.json" 2>/dev/null || echo "0")
    high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$REPORTS_DIR/trivy/trivy-report.json" 2>/dev/null || echo "0")
    
    echo -e "  ${CYAN}Trivy:${NC}"
    echo -e "    CRITICAL: ${RED}$critical${NC}"
    echo -e "    HIGH: ${YELLOW}$high${NC}"
else
    echo -e "  ${YELLOW}⚠ Trivy: Pas de rapport${NC}"
fi

# Grype
if [ -f "$REPORTS_DIR/grype/grype-report.json" ]; then
    matches=$(jq '.matches | length' "$REPORTS_DIR/grype/grype-report.json" 2>/dev/null || echo "0")
    echo -e "\n  ${CYAN}Grype:${NC}"
    echo -e "    Vulnérabilités: ${YELLOW}$matches${NC}"
else
    echo -e "\n  ${YELLOW}⚠ Grype: Pas de rapport${NC}"
fi

# Hadolint
if [ -f "$REPORTS_DIR/hadolint/hadolint-report.json" ]; then
    issues=$(jq 'length' "$REPORTS_DIR/hadolint/hadolint-report.json" 2>/dev/null || echo "0")
    echo -e "\n  ${CYAN}Hadolint (Dockerfile):${NC}"
    echo -e "    Problèmes détectés: ${YELLOW}$issues${NC}"
else
    echo -e "\n  ${YELLOW}⚠ Hadolint: Pas de rapport${NC}"
fi

###############################################################################
# 5. DAST
###############################################################################

print_section "🌐 5. DAST - Tests Dynamiques"

# ZAP
if [ -f "$REPORTS_DIR/zap/zap-baseline-report.json" ]; then
    high_alerts=$(jq '[.site[].alerts[]? | select(.riskcode == "3")] | length' "$REPORTS_DIR/zap/zap-baseline-report.json" 2>/dev/null || echo "0")
    medium_alerts=$(jq '[.site[].alerts[]? | select(.riskcode == "2")] | length' "$REPORTS_DIR/zap/zap-baseline-report.json" 2>/dev/null || echo "0")
    
    echo -e "  ${CYAN}OWASP ZAP:${NC}"
    echo -e "    Alertes HIGH: ${RED}$high_alerts${NC}"
    echo -e "    Alertes MEDIUM: ${YELLOW}$medium_alerts${NC}"
    
    if [ -f "$REPORTS_DIR/zap/zap-baseline-report.html" ]; then
        echo -e "    Rapport HTML: ${BLUE}$REPORTS_DIR/zap/zap-baseline-report.html${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ ZAP: Pas de rapport${NC}"
fi

# Nuclei
if [ -f "$REPORTS_DIR/nuclei/nuclei-report.json" ]; then
    findings=$(wc -l < "$REPORTS_DIR/nuclei/nuclei-report.json" | tr -d ' ')
    echo -e "\n  ${CYAN}Nuclei:${NC}"
    echo -e "    Vulnérabilités détectées: ${YELLOW}$findings${NC}"
else
    echo -e "\n  ${YELLOW}⚠ Nuclei: Pas de rapport${NC}"
fi

###############################################################################
# 6. TLS/Headers
###############################################################################

print_section "🔐 6. TLS/SSL & En-têtes HTTP"

# TestSSL
if [ -f "$REPORTS_DIR/testssl/testssl-report.json" ]; then
    echo -e "  ${CYAN}TestSSL:${NC}"
    echo -e "    Rapport disponible: ${BLUE}$REPORTS_DIR/testssl/testssl-report.html${NC}"
else
    echo -e "  ${YELLOW}⚠ TestSSL: Pas de rapport${NC}"
fi

# SecurityHeaders
if [ -d "$REPORTS_DIR/securityheaders" ] && [ "$(ls -A $REPORTS_DIR/securityheaders 2>/dev/null)" ]; then
    echo -e "\n  ${CYAN}SecurityHeaders:${NC}"
    echo -e "    Rapports disponibles dans: ${BLUE}$REPORTS_DIR/securityheaders/${NC}"
else
    echo -e "\n  ${YELLOW}⚠ SecurityHeaders: Pas de rapport${NC}"
fi

###############################################################################
# 7. Tests API
###############################################################################

print_section "🧪 7. Tests API (Newman/Postman)"

# Newman
if [ -f "$REPORTS_DIR/newman/newman-report.json" ]; then
    total_tests=$(jq '.run.stats.tests.total' "$REPORTS_DIR/newman/newman-report.json" 2>/dev/null || echo "0")
    failed_tests=$(jq '.run.stats.tests.failed' "$REPORTS_DIR/newman/newman-report.json" 2>/dev/null || echo "0")
    passed_tests=$((total_tests - failed_tests))
    
    echo -e "  ${CYAN}Newman (Tests API):${NC}"
    echo -e "    Tests exécutés: ${BLUE}$total_tests${NC}"
    echo -e "    Tests réussis: ${GREEN}$passed_tests${NC}"
    echo -e "    Tests échoués: ${RED}$failed_tests${NC}"
    
    if [ "$failed_tests" -gt 0 ]; then
        echo -e "    ${RED}⚠️  ATTENTION: $failed_tests tests de sécurité API ont échoué${NC}"
        echo -e "    Voir: ${BLUE}$REPORTS_DIR/newman/newman-report.html${NC}"
    else
        echo -e "    ${GREEN}✓ Tous les tests API ont réussi${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ Newman: Pas de rapport${NC}"
    echo -e "    Créez: ${BLUE}tests/api_collection.json${NC}"
fi

###############################################################################
# Résumé final
###############################################################################

print_header "📋 RÉSUMÉ & ACTIONS"

echo -e "${CYAN}Priorités:${NC}\n"

# Compter les problèmes critiques
critical_count=0
high_count=0

# Secrets
if [ -f "$REPORTS_DIR/gitleaks/gitleaks-report.json" ]; then
    secrets=$(jq 'length' "$REPORTS_DIR/gitleaks/gitleaks-report.json" 2>/dev/null || echo "0")
    if [ "$secrets" -gt 0 ]; then
        echo -e "  ${RED}🔴 CRITIQUE: $secrets secrets détectés → Rotation immédiate des credentials${NC}"
        critical_count=$((critical_count + secrets))
    fi
fi

# Dépendances
if [ -f "$REPORTS_DIR/dependency-check/dependency-check-report.json" ]; then
    dep_critical=$(jq '[.dependencies[].vulnerabilities[]? | select(.severity == "CRITICAL")] | length' "$REPORTS_DIR/dependency-check/dependency-check-report.json" 2>/dev/null || echo "0")
    if [ "$dep_critical" -gt 0 ]; then
        echo -e "  ${RED}🔴 CRITIQUE: $dep_critical vulnérabilités critiques dans les dépendances${NC}"
        critical_count=$((critical_count + dep_critical))
    fi
fi

# ZAP
if [ -f "$REPORTS_DIR/zap/zap-baseline-report.json" ]; then
    zap_high=$(jq '[.site[].alerts[]? | select(.riskcode == "3")] | length' "$REPORTS_DIR/zap/zap-baseline-report.json" 2>/dev/null || echo "0")
    if [ "$zap_high" -gt 0 ]; then
        echo -e "  ${YELLOW}🟠 HAUTE: $zap_high vulnérabilités web détectées${NC}"
        high_count=$((high_count + zap_high))
    fi
fi

# Newman API Tests
if [ -f "$REPORTS_DIR/newman/newman-report.json" ]; then
    failed_api=$(jq '.run.stats.tests.failed' "$REPORTS_DIR/newman/newman-report.json" 2>/dev/null || echo "0")
    if [ "$failed_api" -gt 0 ]; then
        echo -e "  ${RED}🔴 CRITIQUE: $failed_api tests de sécurité API ont échoué${NC}"
        critical_count=$((critical_count + failed_api))
    fi
fi

# Message final
echo -e "\n${CYAN}Prochaines étapes:${NC}\n"

if [ "$critical_count" -gt 0 ]; then
    echo -e "  ${RED}1. 🚨 Traiter immédiatement les $critical_count problèmes critiques${NC}"
    echo -e "  ${YELLOW}2. Planifier la correction des $high_count problèmes haute priorité${NC}"
    echo -e "  ${BLUE}3. Relancer un scan après corrections${NC}"
else
    echo -e "  ${GREEN}✓ Aucun problème critique détecté${NC}"
    if [ "$high_count" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠ $high_count problèmes de haute priorité à traiter${NC}"
    fi
fi

echo -e "\n${CYAN}Rapports détaillés:${NC}"
echo -e "  ${BLUE}./reports/${NC}"
echo -e "  ${BLUE}./reports/security-report-*.md${NC}"

echo -e "\n${CYAN}Pour ouvrir les rapports HTML:${NC}"
echo -e "  ${BLUE}open reports/zap/zap-baseline-report.html${NC}"
echo -e "  ${BLUE}open reports/dependency-check/dependency-check-report.html${NC}"
echo -e "  ${BLUE}open reports/testssl/testssl-report.html${NC}"
echo -e "  ${BLUE}open reports/newman/newman-report.html${NC}"

echo ""
