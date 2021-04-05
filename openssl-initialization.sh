#Install openssl

#Inspired by https://github.com/mvallim/kubernetes-under-the-hood/blob/master/documentation/ca-external-infrastructure.md

#Create the profiles
cat <<EOF > config.conf
[ req ]
default_bits            = 2048
default_md              = sha256
distinguished_name      = dn
prompt                  = no

[ dn ]
C                       = US
ST                      = TX
L                       = Sugar Land
O                       = Cloud Ruler
OU                      = \${ENV::OU}
CN                      = \${ENV::CN}

[ root ]
basicConstraints        = critical,CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
keyUsage                = critical,digitalSignature,keyEncipherment,keyCertSign,cRLSign

[ ca ]
basicConstraints        = critical,CA:TRUE,pathlen:0
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer:always
keyUsage                = critical,digitalSignature,keyEncipherment,keyCertSign,cRLSign

[ server ]
subjectKeyIdentifier    = hash
basicConstraints        = critical,CA:FALSE
extendedKeyUsage        = serverAuth
keyUsage                = critical,keyEncipherment,dataEncipherment
authorityKeyIdentifier  = keyid,issuer:always
subjectAltName          = DNS:localhost,\${ENV::SAN},IP:127.0.0.1,IP:127.0.1.1

[ peer ]
subjectKeyIdentifier    = hash
basicConstraints        = critical,CA:FALSE
extendedKeyUsage        = serverAuth,clientAuth
keyUsage                = critical,keyEncipherment,dataEncipherment
authorityKeyIdentifier  = keyid,issuer:always
subjectAltName          = DNS:localhost,\${ENV::SAN},IP:127.0.0.1,IP:127.0.1.1

[ user ]
subjectKeyIdentifier    = hash
basicConstraints        = critical,CA:FALSE
extendedKeyUsage        = clientAuth
keyUsage                = critical,keyEncipherment,dataEncipherment
authorityKeyIdentifier  = keyid,issuer:always
EOF

#Create the root CA
CN="Cloud Ruler Root CA"
OU="Cloud Ruler"
SAN=
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout root-key.pem \
        -days 3650 \
        -config config.conf \
        -extensions root \
        -out root-cert.pem

OU="Cloud Ruler Kubernetes"
#Create k8s CA CSR
CN="Cloud Ruler Kubernetes CA"
SAN=
    openssl req -newkey rsa:2048 -nodes \
        -keyout ca-kubernetes-key.pem \
        -config config.conf \
        -out ca-kubernetes-cert.csr

#Sign the k8s CA certificate with root CA certificate
    openssl x509 -req \
        -extfile config.conf \
        -extensions ca \
        -in ca-kubernetes-cert.csr \
        -CA root-cert.pem \
        -CAkey root-key.pem \
        -CAcreateserial \
        -out ca-kubernetes-cert.pem \
        -days 3650 -sha256
#Create the intermediate k8s CA certificate chain
cat ca-kubernetes-cert.pem root-cert.pem > ca-kubernetes-chain-cert.pem

#Create k8s front proxy CA CSR
CN="Cloud Ruler Kubernetes front proxy CA"
SAN=
    openssl req -newkey rsa:2048 -nodes \
        -keyout ca-kubernetes-front-proxy-key.pem \
        -config config.conf \
        -out ca-kubernetes-front-proxy-cert.csr

#Sign the k8s front proxy CA certificate with the root CA certificate
    openssl x509 -req \
        -extfile config.conf \
        -extensions ca \
        -in ca-kubernetes-front-proxy-cert.csr \
        -CA root-cert.pem \
        -CAkey root-key.pem \
        -CAcreateserial \
        -out ca-kubernetes-front-proxy-cert.pem \
        -days 3650 -sha256

##Create the intermediate k8s front proxy CA certificate chain
cat ca-kubernetes-front-proxy-cert.pem root-cert.pem > ca-kubernetes-chain-cert.pem

#Create k8s etcd CA CSR
CN="Cloud Ruler etcd CA"
SAN=
    openssl req -newkey rsa:2048 -nodes \
        -keyout ca-etcd-key.pem \
        -config config.conf \
        -out ca-etcd-cert.csr

#Sign the k8s etcd CA certificate with the root CA certificate
    openssl x509 -req \
        -extfile config.conf \
        -extensions ca \
        -in ca-etcd-cert.csr \
        -CA root-cert.pem \
        -CAkey root-key.pem \
        -CAcreateserial \
        -out ca-etcd-cert.pem \
        -days 3650 -sha256

#Create the intermediate etcd-ca CA certificate chain
cat ca-etcd-cert.pem root-cert.pem > ca-etcd-chain-cert.pem

#Create k8s certificate maanger CA
CN="Cloud Ruler Kubernetes Certificate Manager CA"
SAN=
   openssl req -newkey rsa:2048 -nodes \
      -keyout ca-certificate-manager-key.pem \
      -config config.conf \
      -out ca-certificate-manager-cert.csr

#Sign the k8s certificate manager CA certificate with the root CA certificate
   openssl x509 -req \
      -extfile config.conf \
      -extensions ca \
      -in ca-certificate-manager-cert.csr \
      -CA root-cert.pem \
      -CAkey root-key.pem \
      -CAcreateserial \
      -out ca-certificate-manager-cert.pem \
      -days 3650 -sha256

#Create the intermediate certificate CA certificate chain
cat ca-certificate-manager-cert.pem root-cert.pem > ca-certificate-manager-chain-cert.pem

#Verify certificates
for instance in ca-kubernetes ca-kubernetes-front-proxy ca-etcd ca-certificate-manager; do
   openssl verify -CAfile root-cert.pem ${instance}-cert.pem
done

openssl ecparam -name secp521r1 -genkey -noout -out sa.key
openssl ec -in sa.key -outform PEM -pubout -out sa.pub
chmod 0600 sa.key
openssl req -new -sha256 -key sa.key \
            -subj "/CN=system:kube-controller-manager" \
  | openssl x509 -req -sha256 -CA ca.crt -CAkey ca.key -CAcreateserial \
                 -out sa.crt -days 365 -extensions v3_req_client \
                 -extfile ./openssl.cnf