#!/bin/bash

# ==================================================================

# Script para inclusao de servidores no LDAP

# Automated LDAP Server Configuration Script

# ==================================================================

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Colors for output

RED=’\033[0;31m’
GREEN=’\033[0;32m’
YELLOW=’\033[1;33m’
BLUE=’\033[0;34m’
NC=’\033[0m’

# Global variables

hostname=””
matricula=””

# Logging functions

log() { echo -e “${BLUE}[$(date +’%Y-%m-%d %H:%M:%S’)]${NC} $1”; }
error() { echo -e “${RED}[ERROR]${NC} $1” >&2; }
success() { echo -e “${GREEN}[SUCCESS]${NC} $1”; }
warning() { echo -e “${YELLOW}[WARNING]${NC} $1”; }

# Check if script is run as root

check_root() {
if [[ $EUID -ne 0 ]]; then
error “Este script deve ser executado como root”
exit 1
fi
}

# Get hostname

get_hostname() {
hostname=$(hostname)
echo “Hostname atual: $hostname”
}

# Create backup of a file

backup_file() {
local file=”$1”
[[ -f “$file” ]] && cp “$file” “${file}.backup.$(date +%Y%m%d_%H%M%S)” && log “Backup criado para $file”
}

# Step 1: Check firewall status

check_firewall() {
log “=== Primeiro passo - Verificar firewall ===”
echo “Status do systemctl para ufw:”
systemctl status ufw || true
echo -e “\nStatus do ufw:”
ufw status || true
success “Verificacao do firewall concluida”
}

# Step 2: Configure /etc/hosts

configure_hosts() {
log “=== Segundo passo - Ajustar /etc/hosts ===”
backup_file “/etc/hosts”

```
if ! grep -q "LDAP Azure replica SP" /etc/hosts; then
    cat >> /etc/hosts << 'EOF'
```

# LDAP Azure replica SP

10.244.37.199   azldaaplx002    openldapspcloud2.caixa  ldap2
10.244.37.196   azldaaplx001    openldapspcloud1.caixa  ldap1
EOF
success “Entradas LDAP adicionadas ao /etc/hosts”
else
warning “Entradas LDAP ja existem no /etc/hosts”
fi
log “Conteudo atual do /etc/hosts:” && cat /etc/hosts
}

# Step 3: Install SSSD

install_sssd() {
log “=== Terceiro passo - Instalar SSSD ===”
apt-get update && apt-get install -y sssd
success “SSSD instalado com sucesso”
}

# Step 4: Configure SSSD

configure_sssd() {
log “=== Quarto passo - Configurar SSSD ===”
backup_file “/etc/sssd/sssd.conf”

```
cat > /etc/sssd/sssd.conf << EOF
```

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

```
chown root:root /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf
success "Configuracao do SSSD criada com sucesso"
```

}

# Step 5: Validate SSSD configuration

validate_sssd_config() {
log “=== Quinto passo - Validar SSSD ===”
echo “Status do SSSD:” && systemctl status sssd || true
echo -e “\nConteudo do arquivo de configuracao:” && cat /etc/sssd/sssd.conf
echo -e “\nPermissoes do arquivo:” && ls -lh /etc/sssd/sssd.conf
success “Validacao da configuracao do SSSD concluida”
}

# Step 6: Configure certificate

configure_certificate() {
log “=== Sexto passo - Configurar certificado ===”
mkdir -p /opt/keystore

```
cat > /opt/keystore/ca.crt << 'EOF'
```

—–BEGIN CERTIFICATE—–
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
—–END CERTIFICATE—–
EOF

```
success "Certificado configurado com sucesso"
```

}

# Step 7: Validate certificate

validate_certificate() {
log “=== Setimo passo - Validar certificado ===”
echo “Conteudo do certificado:” && cat /opt/keystore/ca.crt
echo -e “\nPermissoes do certificado:” && ls -lh /opt/keystore/ca.crt
success “Validacao do certificado concluida”
}

# Step 8: Configure user home directory

configure_user_home() {
log “=== Oitavo passo - Configurar home do usuario ===”
mkdir -p /caixa/usr/
chown -R root: /caixa/usr/
chmod -R 755 /caixa/usr/
success “Diretorio home do usuario configurado”
}

# Step 9: Configure PAM

configure_pam() {
log “=== Nono passo - Ajustar pamd ===”
backup_file “/etc/pam.d/common-session”

```
if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
    echo "session required        pam_mkhomedir.so        skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session
    success "Configuracao PAM adicionada"
else
    warning "Configuracao PAM ja existe"
fi
```

}

# Step 10: Validate PAM

validate_pam() {
log “=== Decimo passo - Validar pamd ===”
echo “Conteudo do system-auth:”
[[ -f /etc/pam.d/system-auth ]] && cat /etc/pam.d/system-auth || echo “Arquivo system-auth nao encontrado”
echo -e “\nConteudo do common-session:”
[[ -f /etc/pam.d/common-session ]] && cat /etc/pam.d/common-session || echo “Arquivo common-session nao encontrado”
success “Validacao PAM concluida”
}

# Step 11: Enable and start SSSD

enable_start_sssd() {
log “=== Decimo primeiro passo - Habilitar e iniciar SSSD ===”
systemctl start sssd && systemctl enable sssd
success “SSSD habilitado e iniciado”
}

# Step 12: Check SSSD service status

check_sssd_status() {
log “=== Decimo segundo passo - Verificar status do servico ===”
systemctl status sssd
success “Status do SSSD verificado”
}

# Step 13: Validate authentication

validate_authentication() {
log “=== Decimo terceiro passo - Validar autenticacao ===”
echo “Para validar a autenticacao, execute: id "matricula"”
echo “Exemplo: id "123456"”

```
if [[ -n "${matricula:-}" ]]; then
    log "Testando autenticacao para matricula: $matricula"
    id "$matricula" || warning "Falha na autenticacao - verifique se o usuario existe no LDAP"
else
    warning "Teste de autenticacao pulado"
fi
success "Validacao de autenticacao concluida"
```

}

# Step 14: Configure sudoers

configure_sudoers() {
log “=== Decimo quarto passo - Configurar sudoers ===”
mkdir -p /etc/sudoers.d
backup_file “/etc/sudoers.d/01-caixa-users”

```
cat > /etc/sudoers.d/01-caixa-users << 'EOF'
```

# SUDOERS v1.0 - VM Jumpers

Defaults env_reset
Defaults log_host, log_year, logfile=”/var/log/sudo.log”
Defaults lecture=“always”
Defaults badpass_message=“Senha Incorreta, tente novamente”
Defaults passwd_tries=3
Defaults timestamp_timeout=15
Defaults passwd_timeout=5
Defaults insults
Defaults requiretty
Defaults log_input,log_output
Defaults iolog_dir=/var/log/sudo-io/%{user}/%Y%m%d_%H%M%S
Defaults iolog_file=%{seq}
Defaults maxseq=1000

# Aliases

Cmnd_Alias PRIV_ESC = /usr/bin/pkexec, /usr/bin/runuser, /usr/bin/sg
Cmnd_Alias SECURITY = /usr/sbin/useradd, /usr/sbin/userdel, /usr/sbin/usermod, /usr/bin/passwd, /usr/sbin/visudo
Cmnd_Alias SU = /bin/su - root, /bin/su - [a-z][0-9][0-9][0-9][0-9][0-9][0-9]

# Groups

%security ALL = ALL, !PRIV_ESC
%segter ALL = ALL, !PRIV_ESC
%producao ALL = ALL, !/bin/su, !/bin/sh, !/bin/bash, !PRIV_ESC, !SECURITY, !SU
%suporte ALL = (ALL) NOPASSWD: /bin/systemctl start *, /bin/systemctl stop *, /bin/systemctl restart *, /bin/systemctl reload *, /bin/systemctl status *, /usr/bin/tail /var/log/*, /usr/bin/journalctl, /bin/cat /var/log/*

# Users

ssegs01 ALL = ALL, !PRIV_ESC

# Default restrictions

ALL ALL = !SECURITY, !SU
EOF

```
chown root:root /etc/sudoers.d/01-caixa-users
chmod 440 /etc/sudoers.d/01-caixa-users

if visudo -cf /etc/sudoers.d/01-caixa-users; then
    success "Arquivo sudoers criado e validado com sucesso"
else
    error "Erro na sintaxe do arquivo sudoers"
    return 1
fi
```

}

# Step 15: Configure timeout policy

configure_timeout() {
log “=== Decimo quinto passo - Configurar politica de timeout ===”
mkdir -p /etc/profile.d
[[ -f /etc/profile.d/tmout.sh ]] && backup_file “/etc/profile.d/tmout.sh”

```
cat > /etc/profile.d/tmout.sh << 'EOF'
```

#!/bin/bash
if /usr/bin/who am i | /bin/grep -qi [a,c,f,p][0-9][0-9][0-9][0-9][0-9][0-9]; then
export TMOUT=7200
readonly TMOUT
fi
EOF

```
chown root:root /etc/profile.d/tmout.sh
chmod 644 /etc/profile.d/tmout.sh
success "Politica de timeout configurada com sucesso"
```

}

# Step 16: Configure audit script

configure_audit_script() {
log “=== Decimo sexto passo - Configurar script de auditoria ===”

```
cat > /etc/profile.d/caixa.sh << 'EOF'
```

#!/bin/bash

if [[ “${SHELL##*/}” == “bash” ]]; then
HISTTIMEFORMAT=”%d/%m/%y %T -> “
HISTFILESIZE=“5000”
HISTSIZE=””
HISTCONTROL=“ignoredups”
set +o functrace

```
loga() {
    local novocomando
    novocomando=$(history 1 | cut -d'>' -f2- | sed 's/^ *//')

    if [[ $novocomando != "exit" && -n $novocomando && $ULT_COM != "$novocomando" ]]; then
        local REAL user_name
        REAL="${HOSTNAME%%.*} $PWD"
        user_name=$(logname 2>/dev/null || echo "unknown")
        
        if [[ $user_name == "$USER" ]]; then
            logger -p authpriv.notice -t bash -- "[$user_name@$REAL]\$ ${novocomando}"
        else
            logger -p authpriv.notice -t bash -- "[$user_name:$USER@$REAL]# ${novocomando}"
        fi

        if [[ $USER == "root" && $user_name != "root" ]]; then
            local result a
            getent group | grep supadmin | grep "$user_name" >/dev/null 2>&1 || result=1
            a=$(id -g "$user_name" 2>/dev/null || echo "0")
            
            if [[ $result != 0 ]] && [[ ! $a =~ ^(30000004|2100|2101|901|922|918|919|921)$ ]]; then
                echo "Falha de seguranca. Acesso indevido como root por $user_name"
                logger -p authpriv.crit -t bash -- "FALHA DE SEGURANCA: Acesso root indevido de $user_name"
                exit 1
            fi
        fi
        
        export ULT_COM=$novocomando
    fi
}

if [[ -n ${SSH_CLIENT:-} ]]; then
    user_name=$(logname 2>/dev/null || echo "unknown")
    logger -p authpriv.notice -t bash -- "Sessao SSH iniciada: ${SSH_CLIENT} $user_name para $USER"
fi

if [[ $(logname 2>/dev/null) == "root" ]]; then
    logger -p authpriv.crit -t bash -- "ALERTA: Acesso direto como root detectado"
fi

trap loga DEBUG
```

fi
EOF

```
chown root:root /etc/profile.d/caixa.sh
chmod 644 /etc/profile.d/caixa.sh
success "Script de auditoria configurado com sucesso"
```

}

# Main execution function

main() {
log “Iniciando configuracao do servidor LDAP…”

```
check_root
get_hostname

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
echo "1. Verifique os logs: journalctl -u sssd -f"
echo "2. Teste autenticacao: id \"matricula\""
echo "3. Teste conectividade: ldapsearch -x -H ldaps://openldapspcloud1.caixa"
echo "4. Verifique sudo: sudo -l"
echo "5. Reinicie ou execute: source /etc/profile.d/caixa.sh"
```

}

# Handle script interruption

trap ‘error “Script interrompido pelo usuario”; exit 1’ INT

# Execute main function

main “$@”
