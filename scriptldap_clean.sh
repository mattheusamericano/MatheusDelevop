#!/bin/bash

# ==================================================================
# Script para inclusao de servidores no LDAP
# Automated LDAP Server Configuration Script
# ==================================================================


set -e  # Exit on any error
set -u  # Exit on undefined variables

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script deve ser executado como root"
        exit 1
    fi
}

# Function to prompt for hostname
get_hostname() {
    local current_hostname=$(hostname)
    echo "Hostname atual: $current_hostname"
    #read -p "Digite o hostname da maquina (ou pressione Enter para usar '$current_hostname'): " hostname
    #if [[ -z "$hostname" ]]; then
    #    hostname="$current_hostname"
    #fi
    hostname="$current_hostname"
    #echo "Usando hostname: $hostname"
}

# Function to create backup of a file
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backup criado para $file"
    fi
}

# Step 1: Check firewall status
check_firewall() {
    log "=== Primeiro passo - Verificar firewall ==="

    echo "Status do systemctl para ufw:"
    systemctl status ufw || true

    echo -e "\nStatus do ufw:"
    ufw status || true

    success "Verificacao do firewall concluida"
}

# Step 2: Configure /etc/hosts
configure_hosts() {
    log "=== Segundo passo - Ajustar /etc/hosts ==="

    backup_file "/etc/hosts"

    # Check if entries already exist
    if ! grep -q "LDAP Azure replica SP" /etc/hosts; then
        echo "# LDAP Azure replica SP" >> /etc/hosts
        echo "10.244.37.199   azldaaplx002    openldapspcloud2.caixa  ldap2" >> /etc/hosts
        echo "10.244.37.196   azldaaplx001    openldapspcloud1.caixa  ldap1" >> /etc/hosts
        success "Entradas LDAP adicionadas ao /etc/hosts"
    else
        warning "Entradas LDAP ja existem no /etc/hosts"
    fi

    log "Conteudo atual do /etc/hosts:"
    cat /etc/hosts
}

# Step 3: Install SSSD
install_sssd() {
    log "=== Terceiro passo - Instalar SSSD ==="

    apt-get update
    apt-get install -y sssd

    success "SSSD instalado com sucesso"
}

# Step 4: Configure SSSD
configure_sssd() {
    log "=== Quarto passo - Configurar SSSD ==="

    backup_file "/etc/sssd/sssd.conf"

    # Create the SSSD configuration file
    cat > /etc/sssd/sssd.conf << EOF
[domain/default]
debug_level = 2
enumerate = true
ldap_id_use_start_tls = true
cache_credentials = true
dns_resolver_op_timeout = 5
dns_resolver_timeout = 10
ldap_search_base = dc=caixa
id_provider = ldap
auth_provider = ldap
sudo_provider = ldap
ldap_referrals = false
ldap_id_mapping = false
ldap_uri = ldaps://openldapspcloud1.caixa,ldaps://openldapspcloud2.caixa
ldap_tls_cacertdir = /opt/keystore/ca.crt
ldap_tls_reqcert = allow
ldap_access_order = filter
ldap_user_search_base = ou=People,dc=caixa?onelevel?(|(host=${hostname})(host=y)(host=segter)(host=security)(host=suporte)(host=producao))
ldap_group_search_base = ou=Groups,dc=caixa?onelevel?(|(host=${hostname})(host=y)(host=segter)(host=security)(host=suporte)(host=producao))
ldap_default_bind_dn = cn=binduser,dc=caixa
ldap_default_authtok_type = password
ldap_default_authtok = S3gur4nc42011
ldap_connection_expire_timeout = 20
ldap_disable_paging = true
ldap_sudo_search_base = ou=RedHat,ou=SUDOers,dc=caixa
ldap_sudo_full_refresh_interval=10800
ldap_sudo_smart_refresh_interval=600
reconnection_retries = 5
client_idle_timeout = 30
offline_timeout = 35
entry_cache_timeout = 5400
account_cache_expiration = 1

[sssd]
config_file_version = 2
debug_level = 2
sbus_timeout = 1800
services = nss, pam, sudo
reconnection_retries = 3
domains = default

[nss]
filter_users = root,dbus,postfix,sshd,ssegs01,jboss7,logstash,apache,ctmagent,postgres,ihsadmin,wasadmin,db2inst1,db2inst2,db2fenc1,monitordb2,gateway,layer7,ssgconfig,raserv,ssem,fndsrv,ncsnmpd,nfast
filter_groups = root,jboss4,jboss6,jboss7,apache,zabbix,controlm,postgres,logstash,ihsadmin,wasadmin,db2iadm1,db2fadm1,gateway,layer7,pkcs11,ssgconfig,nfast,ncsnmpd,raserv,ssem,fndsrv,ssgconfig_radius_local,ssgconfig_ldap_local
entry_cache_nowait_percentage = 75
memcache_timeout = 600
reconnection_retries = 3

[pam]
pam_verbosity = 2
reconnection_retries = 3
offline_credentials_expiration = 1

[sudo]
debug_level = 2
reconnection_retries = 3

[ssh]
debug_level = 2
reconnection_retries = 3
EOF

    # Set proper permissions
    chown root:root /etc/sssd/sssd.conf
    chmod 600 /etc/sssd/sssd.conf

    success "Configuracao do SSSD criada com sucesso"
}

# Step 5: Validate SSSD configuration
validate_sssd_config() {
    log "=== Quinto passo - Validar SSSD ==="

    echo "Status do SSSD:"
    systemctl status sssd || true

    echo -e "\nConteudo do arquivo de configuracao:"
    cat /etc/sssd/sssd.conf

    echo -e "\nPermissoes do arquivo:"
    ls -lh /etc/sssd/sssd.conf

    success "Validacao da configuracao do SSSD concluida"
}

# Step 6: Configure certificate
configure_certificate() {
    log "=== Sexto passo - Configurar certificado ==="

    # Create keystore directory
    mkdir -p /opt/keystore

    # Create certificate file
    cat > /opt/keystore/ca.crt << 'EOF'
-----BEGIN CERTIFICATE-----
MIIFwTCCA6kCBhJRZbcJ+jANBgkqhkiG9w0BAQsFADCBojELMAkGA1UEBhMCQlIx
CzAJBgNVBAgMAlNQMQ8wDQYDVQQHDAZPc2FzY28xIDAeBgNVBAoMF0NhaXhhIEVj
b25vbWljYSBGZWRlcmFsMRUwEwYDVQQLDAxTZWd1cmFuY2EgU1AxFzAVBgNVBAMM
DkFDIE9QRU5MREFQIFNQMSMwIQYJKoZIhvcNAQkBFhRjZXB0aXNwMDVAbWFpbC5j
YWl4YTAeFw0xNDA4MDgxNzU0MDJaFw00NDA3MzAxNzU0MDJaMIGkMSMwIQYJKoZI
hvcNAQkBFhRjZXB0aXNwMDVAbWFpbC5jYWl4YTEgMB4GA1UECwwXQ2FpeGEgRWNv
bm9taWNhIEZlZGVyYWwxEzARBgNVBAoMCklDUC1CcmFzaWwxETAPBgNVBAcMCEJy
YXNpbGlhMQswCQYDVQQIDAJERjELMAkGA1UEBhMCQlIxGTAXBgNVBAMMEG9wZW5s
ZGFwc3AuY2FpeGEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDByp4+
STp2MBUjC7dMMSeMN0tphcqpDdc2yMD6NSdrzESCBl8sG09/KfK+0YdbgfrxflCL
dUjY6GO4NF/6sRrlF9g56iUNIU5PjCui3N8NTA7QGqWTSR007uESffkSUjZxgPRZ
+eW/p1+UJ/t+KAR4Yt6c/79SgoEqOVM6DbJZFZJ4tfsHiqlmfI50lZwY+5Ow1VbV
qmcsQhNhMUx39aHK7nrA0/blqNu2vmWs2JaUN6dOESatp7lnUm/qE0KUUeZB1YbS
XS8AH8xh6yuqMNDlFGYifMlx2IIXDksm15m2wZNwVE8oGJ7jJSobrQJGymjOObtB
kLKYsdqtyn46TQoYfPwfP2YMqG7rQUB1UUUuVZ3lzKjddHHNqFBM7g0ZmI1YicM0
wXdSZ6vToXcafiUjA+AbZEgs+yJ6XQLJ3cbqpAesdBFqIgZi6JlcyTVTu1icjVS4
kRISF8ZcVQVi4x5b4pTKziMM0nSP8aXLcWmF+7tdokJqY4h/N606k1cTrfnFj2Ux
5aqhoQXeWGhmaUP67hNkrDXF3c9lGZj4wnWm3DdSWSGBTFOz01ksbUD4zg5EfS2N
kktTD2DVVcFqjfYiU+Kp4QxXUEy4/XxVXEnJXnTDQmOiX4ZVHL2ydvu2EXIseQyi
OgLil6wcvb2xUNsGNDeLcVSAb3sEKzVJw3NkvQIDAQABMA0GCSqGSIb3DQEBCwUA
A4ICAQBcxB9gsx7rtzlwjCg9IVyQHz19IO20X51+i24o+JIjtewxx788SYZRlui+
UDD7VepNwYaTZk82WNVQckquBj+c8xMa/jB4qQOuHh5h/apkZukGKP/rJIE2Hx4K
ib+63/QRfbjtRS4sovejZNf1O0W2J5OwJBTfP8krm84cmeqCPFWtKjXVeKPSFJp4
kS+O2VRbd8SrYdsUajRbQxKwiEvvvFl6HiPDsNJvq6sdf//F5/8tw9i4N9LQ1sCG
YHCp/WPuwzS+NtEbutMomVjDheRifu72OnH0Wds2g82JfChAIbOX9DhmKG/6qi5z
5Bpu4eKLueFwxSG8BH1r23t90ur0a9w4vnL6tQxOfAoQlBxXxZ//4arufLEzOOre
oC3Ii49XGU3r85GoKPo/3F8KFqVvTDtihVvAKRNPKNjWC40JZ/SktCqt28x6x29X
Pf9JFpAjShVqXg7T545f2QUPUideIF0LLMQY7QBBdfTLhZJccPZvNs1E5r9Vir3D
CVMv1PcNdmhg4NZsK+VqY2FiHbPNxt7hYSdNWwPU2eRSuieRiGk+V2AAzXbwvAAO
vc3KDXUI0/NLSrnJnzQCYWkmOgXlk8sypma/lgT9ZBgfC2QWYQi/f0fQbsnr5nMg
Rqzgfq4hxFo/dnLr+E5ufCGrSstWauBKP2exxHoYAyv58aznMQ==
-----END CERTIFICATE-----
EOF

    success "Certificado configurado com sucesso"
}

# Step 7: Validate certificate
validate_certificate() {
    log "=== Setimo passo - Validar certificado ==="

    echo "Conteudo do certificado:"
    cat /opt/keystore/ca.crt

    echo -e "\nPermissoes do certificado:"
    ls -lh /opt/keystore/ca.crt

    success "Validacao do certificado concluida"
}

# Step 8: Configure user home directory
configure_user_home() {
    log "=== Oitavo passo - Configurar home do usuario ==="

    mkdir -p /caixa/usr/
    chown -R root: /caixa/usr/
    chmod -R 755 /caixa/usr/

    success "Diretorio home do usuario configurado"
}

# Step 9: Configure PAM
configure_pam() {
    log "=== Nono passo - Ajustar pamd ==="

    backup_file "/etc/pam.d/common-session"

    # Check if entry already exists
    if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
        echo "session required        pam_mkhomedir.so        skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session
        success "Configuracao PAM adicionada"
    else
        warning "Configuracao PAM ja existe"
    fi
}

# Step 10: Validate PAM
validate_pam() {
    log "=== Decimo passo - Validar pamd ==="

    echo "Conteudo do system-auth:"
    cat /etc/pam.d/system-auth 2>/dev/null || echo "Arquivo system-auth nao encontrado"

    echo -e "\nConteudo do common-session:"
    cat /etc/pam.d/common-session 2>/dev/null || echo "Arquivo common-session nao encontrado"

    success "Validacao PAM concluida"
}

# Step 11: Enable and start SSSD
enable_start_sssd() {
    log "=== Decimo primeiro passo - Habilitar e iniciar SSSD ==="

    systemctl start sssd
    systemctl enable sssd

    success "SSSD habilitado e iniciado"
}

# Step 12: Check SSSD service status
check_sssd_status() {
    log "=== Decimo segundo passo - Verificar status do servico ==="

    systemctl status sssd

    success "Status do SSSD verificado"
}

# Step 13: Validate authentication
validate_authentication() {
    log "=== Decimo terceiro passo - Validar autenticacao ==="

    echo "Para validar a autenticacao, execute o comando:"
    echo "id \"matricula\""
    echo ""
    echo "Exemplo: id \"123456\""
    echo ""
    #read -p "Digite uma matricula para testar (ou pressione Enter para pular): " matricula

    if [[ -n "$matricula" ]]; then
        log "Testando autenticacao para matricula: $matricula"
        id "$matricula" || warning "Falha na autenticacao - verifique se o usuario existe no LDAP"
    else
        warning "Teste de autenticacao pulado"
    fi

    success "Validacao de autenticacao concluida"
}

# Step 14: Configure sudoers
configure_sudoers() {
    log "=== Decimo quarto passo - Configurar sudoers ==="

    # Create sudoers.d directory if it doesn't exist
    mkdir -p /etc/sudoers.d

    # Backup existing sudoers file
    backup_file "/etc/sudoers.d/01-caixa-users"

    # Create the sudoers file
    cat > /etc/sudoers.d/01-caixa-users << 'EOF'
# =========================== SUDOERS v1.0 - VM JUmpers ============================
# Data da modificao: 08/07/2025
# Quem modificou: Romulo
# Descritivo Basico: Revisao Geral

###############################################################################
## Override builtin defaults                                                  #
###############################################################################
Defaults        env_reset
Defaults        log_host, log_year, logfile="/var/log/sudo.log"
Defaults        lecture="always"
Defaults        badpass_message="Senha Incorreta, tente novamente"
Defaults        passwd_tries=3
Defaults        timestamp_timeout=15
Defaults        passwd_timeout=5
Defaults        insults
Defaults        requiretty
#####Habilita o sudo-io (Monitorar inodes /var/log)
Defaults        log_input,log_output
Defaults        iolog_dir=/var/log/sudo-io/%{user}/%Y%m%d_%H%M%S
Defaults        iolog_file=%{seq}
Defaults        maxseq=1000


###############################################################################
## Cmnd alias specification                                                   #
###############################################################################
Cmnd_Alias      DANGEROUS = /usr/bin/vi, /usr/bin/vim, /usr/bin/nano, /usr/bin/emacs, \
                            /usr/bin/less, /usr/bin/more, /usr/bin/man, /usr/bin/pager, \
                            /usr/bin/awk, /usr/bin/sed, /usr/bin/python*, /usr/bin/perl, \
                            /usr/bin/ruby, /usr/bin/lua, /usr/bin/gdb, /usr/bin/ftp, \
                            /usr/bin/wget, /usr/bin/curl, /usr/bin/nc, /usr/bin/netcat

Cmnd_Alias      SYSTEMD_CRITICAL = /bin/systemctl * ssh*, /bin/systemctl * sudo*, \
                                   /bin/systemctl * rsyslog*, /bin/systemctl * auditd*

Cmnd_Alias      PKG_MGMT = /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg, \
                           /usr/bin/snap, /usr/bin/flatpak

Cmnd_Alias      NETWORK_TOOLS = /usr/bin/nmap, /usr/bin/netstat, /bin/ss, \
                                /usr/bin/tcpdump, /usr/bin/wireshark

Cmnd_Alias      PRIV_ESC = /usr/bin/pkexec, /usr/bin/runuser, /usr/bin/sg

Cmnd_Alias      SECURITY =  /usr/sbin/useradd, /usr/sbin/userdel, \
                            /usr/sbin/adduser, /usr/sbin/deluser, \
                            /usr/sbin/addgroup, /usr/sbin/delgroup, \
                            /usr/sbin/usermod, /usr/sbin/groupadd, \
                            /usr/sbin/groupdel, /usr/sbin/groupmod, \
                            /usr/bin/passwd, /usr/sbin/vipw, \
                            /usr/sbin/visudo

Cmnd_Alias      SU =        /bin/su - root, /bin/su - [a-z][0-9][0-9][0-9][0-9][0-9][0-9]

Cmnd_Alias      BLOCKSUDO = /bin/cp *sudo*, /usr/bin/head *sudo*, /bin/mv *sudo*, \
                            /bin/cat *sudo*, /usr/bin/tail *sudo*, /usr/bin/pg *sudo*, \
                            /usr/bin/find *sudo*, /bin/vi *sudo*, /usr/bin/vim *sudo*, \
                            /usr/bin/less *sudo*, /bin/more *sudo*, \
                            /bin/cp *shadow*, /usr/bin/head *shadow*, /bin/mv *shadow*, \
                            /bin/cat *shadow*, /usr/bin/tail *shadow*, /usr/bin/pg *shadow*, \
                            /usr/bin/find *shadow*, /bin/vi *shadow*, /usr/bin/vim *shadow*, \
                            /usr/bin/less *shadow*, /bin/more *shadow*, \
                            /bin/cp *ldap*, /usr/bin/head *ldap*, /bin/mv *ldap*, \
                            /bin/cat *ldap*, /usr/bin/tail *ldap*, /usr/bin/pg *ldap*, \
                            /usr/bin/find *ldap*, /bin/vi *ldap*, /usr/bin/vim *ldap*, \
                            /usr/bin/less *ldap*, /bin/more *ldap*, \
                            /bin/cp *slapd*, /usr/bin/head *slapd*, /bin/mv *slapd*, \
                            /bin/cat *slapd*, /usr/bin/tail *slapd*, /usr/bin/pg *slapd*, \
                            /usr/bin/find *slapd*, /bin/vi *slapd*, /usr/bin/vim *slapd*, \
                            /usr/bin/less *slapd*, /bin/more *slapd*, \
                            /bin/cp *nslcd*, /usr/bin/head *nslcd*, /bin/mv *nslcd*, \
                            /bin/cat *nslcd*, /usr/bin/tail *nslcd*, /usr/bin/pg *nslcd*, \
                            /usr/bin/find *nslcd*, /bin/vi *nslcd*, /usr/bin/vim *nslcd*, \
                            /usr/bin/less *nslcd*, /bin/more *nslcd*, \
                            /bin/cp *sssd*, /usr/bin/head *sssd*, /bin/mv *sssd*, \
                            /bin/cat *sssd*, /usr/bin/tail *sssd*, /usr/bin/pg *sssd*, \
                            /usr/bin/find *sssd*, /bin/vi *sssd*, /usr/bin/vim *sssd*, \
                            /usr/bin/less *sssd*, /bin/more *sssd*


###############################################################################
## User privilege specification                                               #
###############################################################################

# ============================================================================
# ADMINISTRATIVE GROUPS - Full privileges with restrictions
# ============================================================================

# Security team - Full access with enhanced security restrictions
%security         ALL = ALL !PRIV_ESC

# System administrators - Full access with security restrictions
%segter           ALL = ALL, !PRIV_ESC

# Production support - Full access but with enhanced restrictions
%producao         ALL = ALL, !/bin/su, !/bin/sh, !/bin/bash, !/bin/dash, \
                       !/bin/zsh, !/usr/bin/fish, !PRIV_ESC, !PKG_MGMT, \
                       !SYSTEMD_CRITICAL, !SECURITY, !BLOCKSUDO, !SU

# Support team (suporte) - Service operations with controlled NOPASSWD access
%suporte          ALL = (ALL) NOPASSWD: /bin/systemctl start *, \
                                        /bin/systemctl stop *, \
                                        /bin/systemctl restart *, \
                                        /bin/systemctl reload *, \
                                        /bin/systemctl status *, \
                                        /usr/bin/tail /var/log/*, \
                                        /usr/bin/journalctl, \
                                        /bin/cat /var/log/*

# Default restrictions for ALL users (must be after specific rules)
ALL               ALL = !SECURITY, !BLOCKSUDO, !SU

# ============================================================================
# INDIVIDUAL USER ACCOUNTS
# ============================================================================

# Specific privileged user account
ssegs01           ALL = ALL, !PRIV_ESC

# Emergency break-glass account (use with extreme caution)
# Uncomment only when needed
# emergency         ALL = (ALL) NOPASSWD: ALL

#============ EOF =============

EOF

    # Set proper permissions
    chown root:root /etc/sudoers.d/01-caixa-users
    chmod 440 /etc/sudoers.d/01-caixa-users

    # Validate sudoers syntax
    if visudo -cf /etc/sudoers.d/01-caixa-users; then
        success "Arquivo sudoers criado e validado com sucesso"
    else
        error "Erro na sintaxe do arquivo sudoers"
        return 1
    fi
}

# Step 15: Configure timeout policy
configure_timeout() {
    log "=== Decimo quinto passo - Configurar politica de timeout ==="

    # Create profile.d directory if it doesn't exist
    mkdir -p /etc/profile.d

    # Backup existing timeout script if it exists
    if [[ -f /etc/profile.d/tmout.sh ]]; then
        backup_file "/etc/profile.d/tmout.sh"
    fi

    # Create the timeout script
    cat > /etc/profile.d/tmout.sh << 'EOF'
# set a 5 min timeout policy for bash shell
#!/bin/bash
# This script will logout all the users in 60 Seconds except oracalls, oramed and oracle users.

if  /usr/bin/who am i|/bin/grep -qi [a,c,f,p][0-9][0-9][0-9][0-9][0-9][0-9] ;then
   export TMOUT=7200
   readonly TMOUT
fi
EOF

    # Set proper permissions
    chown root:root /etc/profile.d/tmout.sh
    chmod 644 /etc/profile.d/tmout.sh

    success "Politica de timeout configurada com sucesso"
}

# Step 16: Configure audit script (caixa.sh)
configure_audit_script() {
    log "=== Decimo sexto passo - Configurar script de auditoria (caixa.sh) ==="

    # Create the audit script
    cat > /etc/profile.d/caixa.sh << 'EOF'
#!/bin/bash

if [[ "${SHELL##*/}" == "bash" ]]; then
    HISTTIMEFORMAT="%d/%m/%y %T -> "
    HISTFILESIZE="5000"
    HISTSIZE=""
    HISTCONTROL="ignoredups"
    set +o functrace

    function loga {
        declare comando
        #comando=`fc -ln -1 -1 2> /dev/null`
        #novocomando=`echo $comando | sed 's/\t //g'`
        novocomando=$(history 1 | cut -d'>' -f2- | sed 's/ //')

        if [[ $novocomando != "exit" && -n $novocomando && $ULT_COM != $novocomando ]]; then
            REAL=$(printf "${HOSTNAME%%.*}")
            REAL="$REAL $PWD"
            if [[ $(logname) == $USER ]]; then
                logger -p authpriv.notice -t bash -i -- "Comando: [$(logname)@$REAL]$ ${novocomando}"
            else
                logger -p authpriv.notice -t bash -i -- "Comando: [$(logname):${USER}@$REAL]# ${novocomando}"
            fi

            if [[ $USER == "root" ]]; then
                if [[ $(logname) != "root" ]]; then
                    getent group | grep supadmin | grep $(logname) > /dev/null
                    result=$?
                    a=$(id -g $(logname))
                    if [[ ! ($result == 0 || $a == "30000004" || $a == "2100" || $a == "2101" || $a == "20000008" || $a == "20000888" || $a == "20000015" || $a == "20000010" || $a == "20000000" || $a == "901" || $a == "30000001" || $a == "20000705" || $a == "20000525" || $a == "922" || $a == "918" || $a == "902" || $a == "30000005" || $a == "30000538" ||  $a == "30000505" || $a == "20001008" || $a == "30000114" || $a == "919" || $a == "921") ]]; then
                        echo "Falha de seguranca. Acesso indevido como root por $(logname)"
                        logger -p authpriv.notice -t bash -i -- "Falha de seguranca. Acesso indevido de root de $(logname)"
                        exit
                    fi
                fi
            else
                return
            fi

            ARMAZENAHISTORICO=6

            if [[ $ULT_COM == "vi "* || $ULT_COM == "vim "* || $ULT_COM == "nano "* ]]; then
                if [[ -f $ULT_EDIT ]]; then
                    realar=$(echo $ULT_EDIT | rev | cut -d'/' -f 1 | rev)
                    realpwd=$(echo $ULT_EDIT | rev | cut -d'/' -f2- | rev)
                    if [[ -n $ULT_EDIT_MD5 ]]; then
                        if [[ $ULT_EDIT_MD5 == $(echo $(md5sum $ULT_EDIT)|cut -d' ' -f1 2>/dev/null) ]]; then
                            #echo O arquivo $ULT_EDIT foi apenas aberto.
                            rm -rf /tmp/.$realar"."$ULT_EDIT_MD5
                        else
                            #echo O arquivo $ULT_EDIT foi aberto e alterado. Bkp realizado em $realpwd/.$realar"."`date +%Y%m%d%H%m%S`.`logname`
                            logger -p authpriv.notice -t bash -i -- "Comando: $(logname) editou o arquivo $ULT_EDIT. Backup em $realpwd/.$realar"."$(date +%Y%m%d%H%m%S).$(logname)"
                            mv /tmp/.$realar"."$ULT_EDIT_MD5 $realpwd/.$realar"."$(date +%Y%m%d%H%m%S).$(logname)
                            curl -s -F "file=@$realpwd/.$realar"."$(date +%Y%m%d%H%m%S).$(logname)" -F "hostname=${HOSTNAME%%.*}" -F "path=$realpwd" -F "arquivo=$realpwd/$realar"."$(date +%Y%m%d%H%m%S).$(logname)" --noproxy '10.122.154.12' http://10.122.154.12/arquivos/index.php 2>&1>/dev/null
                            total=$(ls -l $realpwd/.$realar*|wc -l 2>/dev/null)
                            a=1
                            for i in $realpwd/.$realar*; do
                                if [[ $ARMAZENAHISTORICO -lt $total && $a -le $(expr $total - $ARMAZENAHISTORICO) ]]; then
                                    rm -rf $i
                                fi
                                a=$(expr $a + 1)
                            done
                            #echo Removendo arquivos antigos
                        fi
                    else
                        logger -p authpriv.notice -t bash -i -- "Comando: $(logname) criou o arquivo $ULT_EDIT"
                        #echo O arquivo $ULT_EDIT foi criado. ▒ um novo.
                    fi
                    #else
                    #echo O arquivo $ULT_EDIT foi aberto mais nao foi criado.
                fi
            else
                unset ULT_EDIT
                unset ULT_EDIT_MD5
            fi

            if [[ $novocomando == "vi "* || $novocomando == "vim "* ]]; then
                y=$(echo $novocomando | cut -d' ' -f2)
                realar=$(echo $y | rev | cut -d'/' -f 1 | rev)
                realpwd=$(echo $y | rev | cut -d'/' -f2- | rev)

                if [[ ! $realpwd == *"/"* ]]; then
                    realpwd=$PWD
                fi

                realedit=$realpwd"/"$realar

                if [[ ! -d $realedit ]]; then
                    if [[ ! -f $realedit ]]; then
                        #echo Possivelmente criando arquivo $realedit
                        export ULT_EDIT=$realedit
                    else
                        tamanho=$(expr $(stat -c%s $realedit) / 1000)
                        if [[ ! $tamanho -gt 1000 ]]; then
                            export ULT_EDIT_MD5=$(echo $(md5sum $realedit)|cut -d' ' -f1 2>/dev/null)
                            cp $realedit /tmp/.$realar"."$ULT_EDIT_MD5 2>/dev/null
                            export ULT_EDIT=$realedit
                        fi
                    fi
                    #else
                    #echo Ignorando pois editando um diretorio. Newbie. $realedit
                fi
            fi

            export ULT_COM=$novocomando
        fi
    }


    if [[ -n $SSH_CLIENT ]]; then
        logger -p authpriv.notice -t bash -i -- "Comando: Sessao PRINCIPAL iniciada por: ${SSH_CLIENT} $(logname) para $USER"
    #else
    #    logger -p authpriv.notice -t bash -i -- "Comando: Sessao INTERNA iniciada por: $(logname) para $USER"
    fi

    if [[ $(logname) == "root" ]]; then
        logger -p authpriv.crit -t bash -i -- "Comando: ====== FALHA DE SEGURANCA. ACESSO COMO ROOT DIREITO ====="
    fi

    trap loga DEBUG
fi
EOF

    # Set proper permissions
    chown root:root /etc/profile.d/caixa.sh
    chmod 644 /etc/profile.d/caixa.sh

    success "Script de auditoria (caixa.sh) configurado com sucesso"
}

# Main execution function
main() {
    log "Iniciando configuracao do servidor LDAP..."

    # Check if running as root
    check_root

    # Get hostname for configuration
    #get_hostname

    # Execute all steps
    check_firewall
    configure_hosts
    install_sssd
    configure_sssd
    validate_sssd_config
    configure_certificate
    validate_certificate
    configure_user_home
    configure_pam
    validate_pam
    enable_start_sssd
    check_sssd_status
    validate_authentication
    configure_sudoers
    configure_timeout
    configure_audit_script

    success "Configuracao do servidor LDAP concluida com sucesso!"
    echo ""
    echo "Proximos passos:"
    echo "1. Verifique os logs do SSSD: journalctl -u sssd -f"
    echo "2. Teste a autenticacao com: id \"matricula\""
    echo "3. Verifique a conectividade LDAP: ldapsearch -x -H ldaps://openldapspcloud1.caixa"
    echo "4. Verifique as configuracoes do sudo: sudo -l"
    echo "5. Teste a politica de timeout fazendo login com um usuario LDAP"
    echo "6. Verifique o script de auditoria: cat /etc/profile.d/caixa.sh"
    echo "7. Reinicie o servidor ou execute 'source /etc/profile.d/caixa.sh' para ativar a auditoria"
}

# Trap to handle script interruption
trap 'error "Script interrompido pelo usuario"; exit 1' INT

# Run main function
main "$@"
