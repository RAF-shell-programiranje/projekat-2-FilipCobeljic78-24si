#!/bin/bash
set -e  # Exit on error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
APP_DIR="${SCRIPT_DIR}/app"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory.ini"


log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}"
    echo "================================================================================"
    echo "$1"
    echo "================================================================================"
    echo -e "${NC}"
}

check_prerequisites() {
    log_info "Proveravam preduslov..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v ansible &> /dev/null; then
        missing_tools+=("ansible")
    fi
    
    if ! command -v ansible-playbook &> /dev/null; then
        missing_tools+=("ansible-playbook")
    fi
    
    if ! command -v az &> /dev/null; then
        missing_tools+=("azure-cli")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Sledeći alati nisu instalirani: ${missing_tools[*]}"
        log_info "Molimo instalirajte nedostajuće alate pre pokretanja skripte."
        exit 1
    fi
    
    log_success "Svi preduslov su zadovoljeni!"
}

check_azure_login() {
    log_info "Proveravam Azure autentifikaciju..."
    
    if ! az account show &> /dev/null; then
        log_error "Niste ulogovani na Azure!"
        log_info "Pokrenite: az login"
        exit 1
    fi
    
    local subscription=$(az account show --query name -o tsv)
    log_success "Ulogovani ste na Azure subscription: ${subscription}"
}


provision() {
    print_header "PROVISION: Kreiranje Azure VM-ova sa Terraform"
    
    cd "${TERRAFORM_DIR}"
    
    log_info "Inicijalizujem Terraform..."
    terraform init
    
    log_info "Validacija Terraform konfiguracije..."
    terraform validate
    
    log_info "Prikazujem Terraform plan..."
    terraform plan
    
    log_warning "Da li želite da nastavite sa kreiranjem resursa? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_warning "Provision otkazan od strane korisnika."
        exit 0
    fi
    
    log_info "Primenjujem Terraform konfiguraciju..."
    terraform apply -auto-approve
    
    log_success "Terraform provision završen!"
    
    log_info "Kreiram Ansible inventory iz Terraform output-a..."
    generate_inventory
    
    log_success "Provision korak uspešno završen!"
    
    cd "${SCRIPT_DIR}"
}

generate_inventory() {
    log_info "Generiše se Ansible inventory fajl..."
    
    cd "${TERRAFORM_DIR}"
    
    local app_vm_ip=$(terraform output -raw app_vm_public_ip 2>/dev/null || echo "")
    local monitoring_vm_ip=$(terraform output -raw monitoring_vm_public_ip 2>/dev/null || echo "")
    
    if [ -z "$app_vm_ip" ] || [ -z "$monitoring_vm_ip" ]; then
        log_error "Nije moguće preuzeti IP adrese iz Terraform output-a!"
        exit 1
    fi
    
    log_info "App VM IP: ${app_vm_ip}"
    log_info "Monitoring VM IP: ${monitoring_vm_ip}"
    
    cat > "${INVENTORY_FILE}" << EOF
[app_server]
dummy-service-dev-app-vm ansible_host=${app_vm_ip} ansible_user=azureuser ansible_ssh_private_key_file=~/.ssh/id_rsa private_ip=10.0.1.4

[monitoring_server]
dummy-service-dev-monitoring-vm ansible_host=${monitoring_vm_ip} ansible_user=azureuser ansible_ssh_private_key_file=~/.ssh/id_rsa private_ip=10.0.1.5
EOF
    
    log_success "Ansible inventory kreiran: ${INVENTORY_FILE}"
    
    cd "${SCRIPT_DIR}"
}


deploy() {
    print_header "DEPLOY: Postavljanje aplikacije na VM-ove sa Ansible"
    
    if [ ! -f "${INVENTORY_FILE}" ]; then
        log_error "Ansible inventory ne postoji! Prvo pokrenite './automatic_deploy.sh provision'"
        exit 1
    fi
    
    cd "${ANSIBLE_DIR}"
    
    log_info "Proveravam konekciju sa VM-ovima..."
    ansible all -i inventory.ini -m ping || {
        log_warning "Ping neuspešan. Čekam 30 sekundi da VM-ovi postanu dostupni..."
        sleep 30
        ansible all -i inventory.ini -m ping
    }
    
    log_info "Pokrećem Ansible playbook za deploy aplikacije..."
    ansible-playbook -i inventory.ini deploy-app.yml
    
    log_success "Aplikacija uspešno deploy-ovana!"
    
    cd "${SCRIPT_DIR}"
}


check_status() {
    print_header "CHECK-STATUS: Provera statusa aplikacije"
    
    if [ ! -f "${INVENTORY_FILE}" ]; then
        log_error "Ansible inventory ne postoji! Prvo pokrenite './automatic_deploy.sh provision'"
        exit 1
    fi
    
    cd "${TERRAFORM_DIR}"
    
    local app_vm_ip=$(terraform output -raw app_vm_public_ip 2>/dev/null || echo "")
    
    if [ -z "$app_vm_ip" ]; then
        log_error "Nije moguće preuzeti App VM IP adresu!"
        exit 1
    fi
    
    log_info "Povezujem se na App VM (${app_vm_ip})..."
    
    echo ""
    log_info "=== STATUS DUMMY SERVICE ==="
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no azureuser@${app_vm_ip} \
        "sudo systemctl status dummy-service --no-pager" || true
    
    echo ""
    log_info "=== NEDAVNI LOGOVI (poslednje 20 linija) ==="
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no azureuser@${app_vm_ip} \
        "sudo journalctl -u dummy-service -n 20 --no-pager" || true
    
    echo ""
    log_success "Status provera završena!"
    
    cd "${SCRIPT_DIR}"
}


monitor() {
    print_header "MONITOR: Postavljanje monitoring sistema"
    
    if [ ! -f "${INVENTORY_FILE}" ]; then
        log_error "Ansible inventory ne postoji! Prvo pokrenite './automatic_deploy.sh provision'"
        exit 1
    fi
    
    cd "${ANSIBLE_DIR}"
    
    log_info "Postavljam SSH ključeve između VM-ova za monitoring..."
    setup_monitoring_ssh_keys
    
    log_info "Pokrećem Ansible playbook za monitoring setup..."
    ansible-playbook -i inventory.ini setup-monitoring.yml
    
    log_success "Monitoring sistem uspešno postavljen!"
    
    log_info ""
    log_info "Monitoring konfiguracija:"
    log_info "  - check-service.sh: proverava status servisa svakih 5 minuta"
    log_info "  - parse-logs.sh: analizira logove svakih 10 minuta"
    log_info "  - monitor-resources.sh: prati resurse svakih 15 minuta"
    log_info "  - Email notifikacije: test@mailtrap.io"
    log_info ""
    log_info "Proverite email inbox: https://mailtrap.io/inboxes"
    
    cd "${SCRIPT_DIR}"
}

setup_monitoring_ssh_keys() {
    log_info "Postavljam SSH ključeve za komunikaciju monitoring-vm <-> app-vm..."
    
    cd "${TERRAFORM_DIR}"
    
    local app_vm_ip=$(terraform output -raw app_vm_public_ip 2>/dev/null || echo "")
    local monitoring_vm_ip=$(terraform output -raw monitoring_vm_public_ip 2>/dev/null || echo "")
    
    log_info "Generišem SSH ključ na monitoring-vm..."
    ssh -o StrictHostKeyChecking=no azureuser@${monitoring_vm_ip} \
        "ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa_monitoring -N '' -q" 2>/dev/null || true
    
    local pub_key=$(ssh azureuser@${monitoring_vm_ip} "cat ~/.ssh/id_rsa_monitoring.pub")
    
    log_info "Dodajem public key u app-vm authorized_keys..."
    ssh azureuser@${app_vm_ip} "echo '${pub_key}' >> ~/.ssh/authorized_keys"
    
    log_info "Kopiram SSH ključ u /root/.ssh/ na monitoring-vm..."
    ssh azureuser@${monitoring_vm_ip} \
        "sudo mkdir -p /root/.ssh && sudo cp ~/.ssh/id_rsa_monitoring /root/.ssh/ && sudo chmod 600 /root/.ssh/id_rsa_monitoring"
    
    log_success "SSH ključevi postavljeni!"
    
    cd "${SCRIPT_DIR}"
}


full_deploy() {
    print_header "FULL-DEPLOY: Kompletno postavljanje sistema"
    
    log_info "Pokrećem kompletan deployment proces..."
    echo ""
    
    provision
    echo ""
    
    log_info "Čekam 60 sekundi da VM-ovi budu potpuno spremni..."
    sleep 60
    
    deploy
    echo ""
    
    monitor
    echo ""
    
    log_success "========================================="
    log_success "KOMPLETAN DEPLOYMENT USPEŠNO ZAVRŠEN!"
    log_success "========================================="
    echo ""
    log_info "Možete proveriti status sa: ./automatic_deploy.sh check-status"
}


teardown() {
    print_header "TEARDOWN: Uništavanje svih Azure resursa"
    
    log_warning "UPOZORENJE: Ova operacija će obrisati SVE resurse kreirane Terraform-om!"
    log_warning "Da li ste sigurni? (yes/no)"
    read -r response
    
    if [[ "$response" != "yes" ]]; then
        log_warning "Teardown otkazan."
        exit 0
    fi
    
    cd "${TERRAFORM_DIR}"
    
    log_info "Uništavam resurse sa Terraform destroy..."
    terraform destroy -auto-approve
    
    log_success "Svi resursi su uklonjeni!"
    
    if [ -f "${INVENTORY_FILE}" ]; then
        log_info "Brišem Ansible inventory..."
        rm -f "${INVENTORY_FILE}"
    fi
    
    cd "${SCRIPT_DIR}"
}


show_help() {
    cat << EOF
${CYAN}================================================================================${NC}
${GREEN}automatic_deploy.sh${NC} - Skripta za automatizovano deployment dummy servisa
${CYAN}================================================================================${NC}

${YELLOW}KOMANDE:${NC}

  ${GREEN}provision${NC}
      Kreira Azure VM-ove koristeći Terraform i generiše Ansible inventory.

  ${GREEN}deploy${NC}
      Deploy-uje dummy aplikaciju na VM-ove koristeći Ansible playbook.

  ${GREEN}check-status${NC}
      Proverava status dummy servisa na App VM-u.

  ${GREEN}monitor${NC}
      Postavlja i konfiguriše monitoring sistem (email notifikacije).

  ${GREEN}full-deploy${NC}
      Izvršava sve korake redom: provision → deploy → monitor

  ${GREEN}teardown${NC}
      Uništava sve Azure resurse kreirane Terraform-om.

  ${GREEN}help${NC}
      Prikazuje ovu pomoć.

${YELLOW}PRIMERI:${NC}

  # Kompletan deployment od početka
  ./automatic_deploy.sh full-deploy

  # Samo kreiranje infrastrukture
  ./automatic_deploy.sh provision

  # Samo deploy aplikacije (nakon provision)
  ./automatic_deploy.sh deploy

  # Provera statusa aplikacije
  ./automatic_deploy.sh check-status

  # Uništavanje resursa
  ./automatic_deploy.sh teardown

${YELLOW}PREDUSLOV:${NC}
  - Terraform instaliran
  - Ansible instaliran
  - Azure CLI instaliran i ulogovan (az login)
  - SSH ključ (~/.ssh/id_rsa)

${CYAN}================================================================================${NC}
EOF

}
main() {
    if [ $# -eq 0 ]; then
        log_error "Nedostaje komanda!"
        echo ""
        show_help
        exit 1
    fi
    
    local command=$1
    
    case "$command" in
        provision)
            check_prerequisites
            check_azure_login
            provision
            ;;
        deploy)
            check_prerequisites
            deploy
            ;;
        check-status)
            check_status
            ;;
        monitor)
            check_prerequisites
            monitor
            ;;
        full-deploy)
            check_prerequisites
            check_azure_login
            full_deploy
            ;;
        teardown)
            check_prerequisites
            check_azure_login
            teardown
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Nepoznata komanda: ${command}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
