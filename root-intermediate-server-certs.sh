лэ#!/bin/bash

################################################################################
# Raspberry Pi Zero 2W Certificate Authority Setup
# Creates Root CA, Intermediate CA, and Server Certificate for Nextcloud
# 
# Organization: IT-Not
# Country: Germany (DE)
# State: Baden-Württemberg
# City: Schwäbisch Hall
# Domain: nextcloud.local, nextcloud
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables
COUNTRY="DE"
STATE="Baden-Wuerttemberg"
CITY="Schwaigern"
ORGANIZATION="IT-Not"
ORG_UNIT="IT Security"
EMAIL="admin@nextcloud.local"

# Certificate Validity (in days)
ROOT_CA_DAYS=7300        # 20 years
INTERMEDIATE_CA_DAYS=3650 # 10 years
SERVER_CERT_DAYS=825     # 825 days (maximum for public trust)

# Key sizes
ROOT_KEY_SIZE=4096
INTERMEDIATE_KEY_SIZE=4096
SERVER_KEY_SIZE=2048

# Directories
BASE_DIR="$HOME/nextcloud-pki"
ROOT_CA_DIR="$BASE_DIR/root-ca"
INTERMEDIATE_CA_DIR="$BASE_DIR/intermediate-ca"

# Certificate Names
ROOT_CA_CN="IT-Not Root Certificate Authority"
INTERMEDIATE_CA_CN="IT-Not Intermediate Certificate Authority"
SERVER_CN="nextcloud.local"

# Server Subject Alternative Names
SERVER_SANS="DNS:nextcloud.local,DNS:nextcloud,DNS:localhost,IP:127.0.0.1"

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_requirements() {
    print_header "Checking Requirements"
    
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is not installed"
        echo "Install it with: sudo apt install openssl"
        exit 1
    fi
    
    print_success "OpenSSL found: $(openssl version)"
    
    # Check available disk space (at least 100MB)
    available_space=$(df -m "$HOME" | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 100 ]; then
        print_warning "Low disk space: ${available_space}MB available"
    else
        print_success "Sufficient disk space: ${available_space}MB available"
    fi
}

create_directory_structure() {
    print_header "Creating Directory Structure"
    
    # Create base directories
    mkdir -p "$ROOT_CA_DIR"/{certs,crl,newcerts,private}
    mkdir -p "$INTERMEDIATE_CA_DIR"/{certs,crl,csr,newcerts,private}
    
    # Set restrictive permissions
    chmod 700 "$ROOT_CA_DIR/private"
    chmod 700 "$INTERMEDIATE_CA_DIR/private"
    
    # Initialize databases
    touch "$ROOT_CA_DIR/index.txt"
    touch "$INTERMEDIATE_CA_DIR/index.txt"
    echo 1000 > "$ROOT_CA_DIR/serial"
    echo 1000 > "$INTERMEDIATE_CA_DIR/serial"
    echo 1000 > "$INTERMEDIATE_CA_DIR/crlnumber"
    
    print_success "Directory structure created at $BASE_DIR"
}

create_root_ca_config() {
    print_header "Creating Root CA Configuration"
    
    cat > "$ROOT_CA_DIR/openssl.cnf" << EOF
# OpenSSL Root CA configuration file for IT-Not

[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = $ROOT_CA_DIR
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

private_key       = \$dir/private/ca.key.pem
certificate       = \$dir/certs/ca.cert.pem

crlnumber         = \$dir/crlnumber
crl               = \$dir/crl/ca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

default_md        = sha256
name_opt          = ca_default
cert_opt          = ca_default
default_days      = $ROOT_CA_DAYS
preserve          = no
policy            = policy_strict

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = $ROOT_KEY_SIZE
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256
x509_extensions     = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

countryName_default             = $COUNTRY
stateOrProvinceName_default     = $STATE
localityName_default            = $CITY
0.organizationName_default      = $ORGANIZATION
organizationalUnitName_default  = $ORG_UNIT
emailAddress_default            = $EMAIL

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ crl_ext ]
authorityKeyIdentifier=keyid:always

[ ocsp ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF

    print_success "Root CA configuration created"
}

create_intermediate_ca_config() {
    print_header "Creating Intermediate CA Configuration"
    
    cat > "$INTERMEDIATE_CA_DIR/openssl.cnf" << EOF
# OpenSSL Intermediate CA configuration file for IT-Not

[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = $INTERMEDIATE_CA_DIR
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

private_key       = \$dir/private/intermediate.key.pem
certificate       = \$dir/certs/intermediate.cert.pem

crlnumber         = \$dir/crlnumber
crl               = \$dir/crl/intermediate.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

default_md        = sha256
name_opt          = ca_default
cert_opt          = ca_default
default_days      = $SERVER_CERT_DAYS
preserve          = no
policy            = policy_loose

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = $INTERMEDIATE_KEY_SIZE
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

countryName_default             = $COUNTRY
stateOrProvinceName_default     = $STATE
localityName_default            = $CITY
0.organizationName_default      = $ORGANIZATION
organizationalUnitName_default  = $ORG_UNIT
emailAddress_default            = $EMAIL

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "IT-Not Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = nextcloud.local
DNS.2 = nextcloud
DNS.3 = localhost
DNS.4 = nextcloud.tail70fc28.ts.net
IP.1 = 127.0.0.1

[ crl_ext ]
authorityKeyIdentifier=keyid:always

[ ocsp ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF

    print_success "Intermediate CA configuration created"
}

create_root_ca() {
    print_header "Creating Root CA"
    
    print_info "Generating Root CA private key (${ROOT_KEY_SIZE}-bit)..."
    print_warning "You will be prompted to set a passphrase for the Root CA private key"
    print_warning "IMPORTANT: Remember this passphrase - you'll need it to sign certificates!"
    
    openssl genrsa -aes256 \
        -out "$ROOT_CA_DIR/private/ca.key.pem" \
        $ROOT_KEY_SIZE
    
    chmod 400 "$ROOT_CA_DIR/private/ca.key.pem"
    print_success "Root CA private key created"
    
    print_info "Generating Root CA certificate..."
    print_warning "Enter the Root CA private key passphrase when prompted"
    
    openssl req -config "$ROOT_CA_DIR/openssl.cnf" \
        -key "$ROOT_CA_DIR/private/ca.key.pem" \
        -new -x509 -days $ROOT_CA_DAYS -sha256 \
        -extensions v3_ca \
        -out "$ROOT_CA_DIR/certs/ca.cert.pem" \
        -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORG_UNIT/CN=$ROOT_CA_CN/emailAddress=$EMAIL"
    
    chmod 444 "$ROOT_CA_DIR/certs/ca.cert.pem"
    print_success "Root CA certificate created"
    
    # Display certificate info
    print_info "Root CA Certificate Details:"
    openssl x509 -noout -text -in "$ROOT_CA_DIR/certs/ca.cert.pem" | grep -E "Subject:|Issuer:|Not Before|Not After"
}

create_intermediate_ca() {
    print_header "Creating Intermediate CA"
    
    print_info "Generating Intermediate CA private key (${INTERMEDIATE_KEY_SIZE}-bit)..."
    print_warning "You will be prompted to set a passphrase for the Intermediate CA private key"
    
    openssl genrsa -aes256 \
        -out "$INTERMEDIATE_CA_DIR/private/intermediate.key.pem" \
        $INTERMEDIATE_KEY_SIZE
    
    chmod 400 "$INTERMEDIATE_CA_DIR/private/intermediate.key.pem"
    print_success "Intermediate CA private key created"
    
    print_info "Creating Intermediate CA certificate signing request..."
    print_warning "Enter the Intermediate CA private key passphrase when prompted"
    
    openssl req -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
        -new -sha256 \
        -key "$INTERMEDIATE_CA_DIR/private/intermediate.key.pem" \
        -out "$INTERMEDIATE_CA_DIR/csr/intermediate.csr.pem" \
        -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORG_UNIT/CN=$INTERMEDIATE_CA_CN/emailAddress=$EMAIL"
    
    print_success "Intermediate CA CSR created"
    
    print_info "Signing Intermediate CA certificate with Root CA..."
    print_warning "Enter the ROOT CA private key passphrase when prompted"
    
    openssl ca -config "$ROOT_CA_DIR/openssl.cnf" \
        -extensions v3_intermediate_ca \
        -days $INTERMEDIATE_CA_DAYS -notext -md sha256 \
        -in "$INTERMEDIATE_CA_DIR/csr/intermediate.csr.pem" \
        -out "$INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem" \
        -batch
    
    chmod 444 "$INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem"
    print_success "Intermediate CA certificate signed and created"
    
    # Create certificate chain
    print_info "Creating certificate chain file..."
    cat "$INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem" \
        "$ROOT_CA_DIR/certs/ca.cert.pem" \
        > "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem"
    
    chmod 444 "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem"
    print_success "Certificate chain created"
    
    # Verify intermediate certificate
    print_info "Verifying Intermediate CA certificate..."
    openssl verify -CAfile "$ROOT_CA_DIR/certs/ca.cert.pem" \
        "$INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem"
}

create_server_certificate() {
    print_header "Creating Nextcloud Server Certificate"
    
    print_info "Generating server private key (${SERVER_KEY_SIZE}-bit)..."
    
    openssl genrsa \
        -out "$INTERMEDIATE_CA_DIR/private/nextcloud.local.key.pem" \
        $SERVER_KEY_SIZE
    
    chmod 400 "$INTERMEDIATE_CA_DIR/private/nextcloud.local.key.pem"
    print_success "Server private key created"
    
    print_info "Creating server certificate signing request..."
    
    openssl req -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
        -key "$INTERMEDIATE_CA_DIR/private/nextcloud.local.key.pem" \
        -new -sha256 \
        -out "$INTERMEDIATE_CA_DIR/csr/nextcloud.local.csr.pem" \
        -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORG_UNIT/CN=$SERVER_CN/emailAddress=$EMAIL"
    
    print_success "Server CSR created"
    
    print_info "Signing server certificate with Intermediate CA..."
    print_warning "Enter the INTERMEDIATE CA private key passphrase when prompted"
    
    openssl ca -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
        -extensions server_cert \
        -days $SERVER_CERT_DAYS -notext -md sha256 \
        -in "$INTERMEDIATE_CA_DIR/csr/nextcloud.local.csr.pem" \
        -out "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem" \
        -batch
    
    chmod 444 "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem"
    print_success "Server certificate signed and created"
    
    # Create full chain certificate
    print_info "Creating full chain certificate for Nextcloud..."
    cat "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem" \
        "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem" \
        > "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.fullchain.pem"
    
    chmod 444 "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.fullchain.pem"
    print_success "Full chain certificate created"
    
    # Verify server certificate
    print_info "Verifying server certificate..."
    openssl verify -CAfile "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem" \
        "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem"
}

create_deployment_package() {
    print_header "Creating Deployment Package"
    
    DEPLOY_DIR="$BASE_DIR/deployment"
    mkdir -p "$DEPLOY_DIR"/{nextcloud,ca-certificates}
    
    # Copy server files
    cp "$INTERMEDIATE_CA_DIR/private/nextcloud.local.key.pem" \
        "$DEPLOY_DIR/nextcloud/nextcloud.key.pem"
    cp "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem" \
        "$DEPLOY_DIR/nextcloud/nextcloud.cert.pem"
    cp "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.fullchain.pem" \
        "$DEPLOY_DIR/nextcloud/nextcloud.fullchain.pem"
    
    # Copy CA certificates
    cp "$ROOT_CA_DIR/certs/ca.cert.pem" \
        "$DEPLOY_DIR/ca-certificates/root-ca.cert.pem"
    cp "$INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem" \
        "$DEPLOY_DIR/ca-certificates/intermediate-ca.cert.pem"
    cp "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem" \
        "$DEPLOY_DIR/ca-certificates/ca-chain.cert.pem"
    
    # Create README
    cat > "$DEPLOY_DIR/README.txt" << EOF
IT-Not Certificate Deployment Package for Nextcloud
====================================================

Generated: $(date)
Organization: $ORGANIZATION
Server: $SERVER_CN

Directory Structure:
--------------------
nextcloud/
  - nextcloud.key.pem          : Server private key (keep secure!)
  - nextcloud.cert.pem         : Server certificate
  - nextcloud.fullchain.pem    : Server certificate + CA chain (recommended for web servers)

ca-certificates/
  - root-ca.cert.pem           : Root CA certificate (install in trusted store)
  - intermediate-ca.cert.pem   : Intermediate CA certificate
  - ca-chain.cert.pem          : Complete CA chain

Installation Instructions:
--------------------------

1. For Nextcloud Server (Apache):
   sudo cp nextcloud/nextcloud.cert.pem /etc/ssl/certs/
   sudo cp nextcloud/nextcloud.fullchain.pem /etc/ssl/certs/
   sudo cp nextcloud/nextcloud.key.pem /etc/ssl/private/
   sudo chmod 600 /etc/ssl/private/nextcloud.key.pem

   Configure Apache SSL:
   SSLCertificateFile /etc/ssl/certs/nextcloud.cert.pem
   SSLCertificateKeyFile /etc/ssl/private/nextcloud.key.pem
   SSLCertificateChainFile /etc/ssl/certs/nextcloud.fullchain.pem

2. For Nextcloud Server (Nginx):
   sudo cp nextcloud/nextcloud.fullchain.pem /etc/ssl/certs/
   sudo cp nextcloud/nextcloud.key.pem /etc/ssl/private/
   sudo chmod 600 /etc/ssl/private/nextcloud.key.pem

   Configure Nginx SSL:
   ssl_certificate /etc/ssl/certs/nextcloud.fullchain.pem;
   ssl_certificate_key /etc/ssl/private/nextcloud.key.pem;

3. Install Root CA on Clients:
   
   Linux:
   sudo cp ca-certificates/root-ca.cert.pem /usr/local/share/ca-certificates/it-not-root-ca.crt
   sudo update-ca-certificates

   Windows:
   Import root-ca.cert.pem into "Trusted Root Certification Authorities"
   Run: certlm.msc (as Administrator)

   macOS:
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca-certificates/root-ca.cert.pem

   Android:
   Settings > Security > Install certificates > CA certificate

Certificate Validity:
---------------------
Server Certificate Valid: $SERVER_CERT_DAYS days (~$(($SERVER_CERT_DAYS/365)) years)
Expires: $(date -d "+$SERVER_CERT_DAYS days" +%Y-%m-%d)

Renewal:
--------
Before expiration, generate a new server certificate using:
cd $INTERMEDIATE_CA_DIR
./renew-nextcloud-cert.sh

Support:
--------
For issues, contact: $EMAIL
EOF

    print_success "Deployment package created at: $DEPLOY_DIR"
}

create_renewal_script() {
    print_header "Creating Certificate Renewal Script"
    
    cat > "$INTERMEDIATE_CA_DIR/renew-nextcloud-cert.sh" << 'EOFSCRIPT'
#!/bin/bash

# Certificate Renewal Script for Nextcloud
# Run this script to renew the Nextcloud server certificate

set -e

INTERMEDIATE_CA_DIR="$(dirname "$0")"
SERVER_CN="nextcloud.local"
SERVER_CERT_DAYS=1825

echo "=== Nextcloud Certificate Renewal ==="
echo ""

# Check if old certificate exists
if [ ! -f "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem" ]; then
    echo "Error: Current certificate not found"
    exit 1
fi

# Display current certificate expiry
echo "Current certificate expires:"
openssl x509 -noout -enddate -in "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem"
echo ""

# Backup old certificate
BACKUP_DIR="$INTERMEDIATE_CA_DIR/certs/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem" "$BACKUP_DIR/"
cp "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.fullchain.pem" "$BACKUP_DIR/"
echo "Old certificate backed up to: $BACKUP_DIR"
echo ""

# Generate new CSR with existing private key
echo "Generating new certificate signing request..."
openssl req -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
    -key "$INTERMEDIATE_CA_DIR/private/nextcloud.local.key.pem" \
    -new -sha256 \
    -out "$INTERMEDIATE_CA_DIR/csr/nextcloud.local-renew.csr.pem" \
    -subj "/C=DE/ST=Baden-Wuerttemberg/L=Schwaigern/O=IT-Not/OU=IT Security/CN=$SERVER_CN/emailAddress=admin@nextcloud.local"

echo "Signing new certificate..."
echo "You will be prompted for the Intermediate CA private key passphrase"

openssl ca -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
    -extensions server_cert \
    -days $SERVER_CERT_DAYS -notext -md sha256 \
    -in "$INTERMEDIATE_CA_DIR/csr/nextcloud.local-renew.csr.pem" \
    -out "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem" \
    -batch

# Create new full chain
cat "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem" \
    "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem" \
    > "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.fullchain.pem"

echo ""
echo "✓ Certificate renewed successfully!"
echo ""
echo "New certificate expires:"
openssl x509 -noout -enddate -in "$INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem"
echo ""
echo "Next steps:"
echo "1. Copy new certificate to web server"
echo "2. Reload web server configuration"
echo "3. Verify certificate in browser"
EOFSCRIPT

    chmod +x "$INTERMEDIATE_CA_DIR/renew-nextcloud-cert.sh"
    print_success "Renewal script created"
}

display_summary() {
    print_header "Setup Complete!"
    
    echo ""
    echo -e "${GREEN}✓ Certificate Authority successfully created on Raspberry Pi Zero 2W${NC}"
    echo ""
    echo "Directory Structure:"
    echo "===================="
    echo "$BASE_DIR/"
    echo "├── root-ca/                    # Root CA (keep secure!)"
    echo "│   ├── certs/ca.cert.pem      # Root CA certificate"
    echo "│   └── private/ca.key.pem     # Root CA private key"
    echo "├── intermediate-ca/            # Intermediate CA"
    echo "│   ├── certs/"
    echo "│   │   ├── intermediate.cert.pem    # Intermediate CA cert"
    echo "│   │   ├── ca-chain.cert.pem        # Complete CA chain"
    echo "│   │   ├── nextcloud.local.cert.pem # Server certificate"
    echo "│   │   └── nextcloud.local.fullchain.pem # Server + chain"
    echo "│   └── private/"
    echo "│       ├── intermediate.key.pem     # Intermediate CA key"
    echo "│       └── nextcloud.local.key.pem  # Server private key"
    echo "└── deployment/                 # Ready-to-deploy files"
    echo "    ├── nextcloud/              # Server certificates"
    echo "    └── ca-certificates/        # CA certificates for clients"
    echo ""
    
    echo "Certificate Details:"
    echo "===================="
    echo -e "${BLUE}Root CA:${NC}"
    echo "  Subject: C=$COUNTRY, ST=$STATE, L=$CITY, O=$ORGANIZATION, CN=$ROOT_CA_CN"
    echo "  Valid for: $ROOT_CA_DAYS days (~$((ROOT_CA_DAYS/365)) years)"
    echo ""
    echo -e "${BLUE}Intermediate CA:${NC}"
    echo "  Subject: C=$COUNTRY, ST=$STATE, L=$CITY, O=$ORGANIZATION, CN=$INTERMEDIATE_CA_CN"
    echo "  Valid for: $INTERMEDIATE_CA_DAYS days (~$((INTERMEDIATE_CA_DAYS/365)) years)"
    echo ""
    echo -e "${BLUE}Server Certificate:${NC}"
    echo "  Common Name: $SERVER_CN"
    echo "  SANs: nextcloud.local, nextcloud, localhost"
    echo "  Valid for: $SERVER_CERT_DAYS days (~$((SERVER_CERT_DAYS/365)) years)"
    echo ""
    
    echo "Next Steps:"
    echo "==========="
    echo "1. Deploy certificates to Nextcloud server:"
    echo "   Files are in: $DEPLOY_DIR"
    echo ""
    echo "2. Install Root CA on client devices:"
    echo "   Use: $DEPLOY_DIR/ca-certificates/root-ca.cert.pem"
    echo ""
    echo "3. Configure Nextcloud web server with SSL certificates"
    echo ""
    echo "4. Set up certificate renewal reminder (before $(date -d "+$SERVER_CERT_DAYS days" +%Y-%m-%d))"
    echo ""
    
    echo "Verification Commands:"
    echo "======================"
    echo "# Verify certificate chain"
    echo "openssl verify -CAfile $INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem \\"
    echo "  $INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem"
    echo ""
    echo "# View certificate details"
    echo "openssl x509 -noout -text -in $INTERMEDIATE_CA_DIR/certs/nextcloud.local.cert.pem"
    echo ""
    echo "# Test server certificate (after deployment)"
    echo "openssl s_client -connect nextcloud.local:443 -CAfile $DEPLOY_DIR/ca-certificates/root-ca.cert.pem"
    echo ""
    
    echo "Security Reminders:"
    echo "==================="
    echo "🔒 Backup the entire PKI directory securely"
    echo "🔒 Store Root CA private key passphrase safely"
    echo "🔒 Keep Root CA offline when not needed"
    echo "🔒 Set up monitoring for certificate expiration"
    echo "🔒 Review security best practices for Raspberry Pi"
    echo ""
    
    print_success "All certificates created successfully!"
    echo ""
    echo "Deployment package available at: $DEPLOY_DIR"
    echo "Review the README.txt in the deployment directory for installation instructions."
}

################################################################################
# Main Execution
################################################################################

main() {
    clear
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   Raspberry Pi Zero 2W Certificate Authority Setup        ║"
    echo "║   Organization: IT-Not                                     ║"
    echo "║   Domain: nextcloud.local                                  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    print_warning "This script will create a complete PKI infrastructure"
    print_warning "You will be prompted for passphrases multiple times"
    print_warning "Make sure to remember or securely store these passphrases!"
    echo ""
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    echo ""
    
    check_requirements
    create_directory_structure
    create_root_ca_config
    create_intermediate_ca_config
    create_root_ca
    create_intermediate_ca
    create_server_certificate
    create_deployment_package
    create_renewal_script
    display_summary
}

# Run main function
main "$@"