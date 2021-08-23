# -----------------------------------------------------------------------------
# CERTIFICATES.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
cd

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[[ "$DONT_RUN_CERTIFICATES" = true ]] && exit

echo
echo "---------------------- CERTIFICATES -----------------------"

# -----------------------------------------------------------------------------
# EXTERNAL IP
# -----------------------------------------------------------------------------
EXTERNAL_IP=$(dig -4 +short myip.opendns.com a @resolver1.opendns.com) || true
echo EXTERNAL_IP="$EXTERNAL_IP" >> $INSTALLER/000-source

# -----------------------------------------------------------------------------
# SELF-SIGNED CERTIFICATE
# -----------------------------------------------------------------------------
cd /root/eb-ssl
rm -f /root/eb-ssl/eb-kratos.*

# the extension file for multiple hosts:
# the container IP, the host IP and the host names
cat >eb-kratos.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
EOF

# FQDNs
echo "DNS.1 = $KRATOS_FQDN" >>eb-kratos.ext
echo "DNS.2 = $SECUREAPP_FQDN" >>eb-kratos.ext

# internal IPs
i=1
for addr in $(egrep '^address=' /etc/dnsmasq.d/eb-kratos); do
    ip=$(echo $addr | rev | cut -d '/' -f1 | rev)
    echo "IP.$i = $ip" >> eb-kratos.ext
    (( i += 1 ))
done

# external IPs
echo "IP.$i = $REMOTE_IP" >>eb-kratos.ext
(( i += 1 ))
[[ -n "$EXTERNAL_IP" ]] && [[ "$EXTERNAL_IP" != "$REMOTE_IP" ]] \
    && echo "IP.$i = $EXTERNAL_IP" >>eb-kratos.ext \
    || true

# the domain key and the domain certificate
openssl req -nodes -newkey rsa:2048 \
    -keyout eb-kratos.key -out eb-kratos.csr \
    -subj "/O=emrah-bullseye/OU=jitsi/CN=$JITSI_HOST"
openssl x509 -req -CA eb-CA.pem -CAkey eb-CA.key -CAcreateserial -days 10950 \
    -in eb-kratos.csr -out eb-kratos.pem -extfile eb-kratos.ext