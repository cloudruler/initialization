#Install cfssl first
#expects file "password"

echo "Root CA CSR config"
cat > root-csr.json <<EOF
{
  "CN": "Cloud Ruler Root CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "Cloud Ruler",
      "OU": "Cloud Ruler Root CA",
      "ST": "Texas"
    }
  ]
}
EOF
echo "Create .csr, key, and cert"
cfssl gencert -initca root-csr.json | cfssljson -bare root

#########################################

echo "Profile JSON"
cat > cfssl.json <<EOF
{
  "signing" : {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "intermediate_ca": {
        "usages": ["signing", "digital signature", "key encipherment", "cert sign", "crl sign", "server auth", "client auth"],
        "expiry": "87600h",
        "ca_constraint": {
            "is_ca": true,
            "max_path_len": 0, 
            "max_path_len_zero": true
        }
      },
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "87600h"
      }
    }
  }
}
EOF

#########################################

echo "k8s CA CSR config"
cat > ca-kubernetes-csr.json <<EOF
{
  "CN": "Cloud Ruler Kubernetes CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "Cloud Ruler",
      "OU": "Cloud Ruler Kubernetes CA",
      "ST": "Texas"
    }
  ]
}
EOF

echo "Create .csr, key, and cert files"
cfssl gencert -initca ca-kubernetes-csr.json | cfssljson -bare ca-kubernetes
echo "Sign certificate with root ca"
cfssl sign -ca root.pem -ca-key root-key.pem -config cfssl.json -profile intermediate_ca ca-kubernetes.csr | cfssljson -bare ca-kubernetes

#########################################

echo "k8s front proxy CA CSR config"
cat > ca-kubernetes-front-proxy-csr.json <<EOF
{
  "CN": "Cloud Ruler Kubernetes front proxy CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "Cloud Ruler",
      "OU": "Cloud Ruler Kubernetes front proxy CA",
      "ST": "Texas"
    }
  ]
}
EOF

echo "Create .csr, key, and cert files"
cfssl gencert -initca ca-kubernetes-front-proxy-csr.json | cfssljson -bare ca-kubernetes-front-proxy
echo "Sign certificate with root ca"
cfssl sign -ca root.pem -ca-key root-key.pem -config cfssl.json -profile intermediate_ca ca-kubernetes-front-proxy.csr | cfssljson -bare ca-kubernetes-front-proxy

#########################################

echo "k8s etcd CA CSR config"
cat > ca-etcd-csr.json <<EOF
{
  "CN": "Cloud Ruler etcd CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "Cloud Ruler",
      "OU": "Cloud Ruler etcd CA",
      "ST": "Texas"
    }
  ]
}
EOF

echo "Create .csr, key, and cert files"
cfssl gencert -initca ca-etcd-csr.json | cfssljson -bare ca-etcd
echo "Sign certificate with root ca"
cfssl sign -ca root.pem -ca-key root-key.pem -config cfssl.json -profile intermediate_ca ca-etcd.csr | cfssljson -bare ca-etcd

#########################################

echo "k8s certificate manager CA CSR config"
cat > ca-certificate-manager-csr.json <<EOF
{
  "CN": "Cloud Ruler Kubernetes Certificate Manager CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "Cloud Ruler",
      "OU": "Cloud Ruler Kubernetes Certificate Manager CA",
      "ST": "Texas"
    }
  ]
}
EOF

echo "Create .csr, key, and cert files"
cfssl gencert -initca ca-certificate-manager-csr.json | cfssljson -bare ca-certificate-manager
echo "Sign certificate with root ca"
cfssl sign -ca root.pem -ca-key root-key.pem -config cfssl.json -profile intermediate_ca ca-certificate-manager.csr | cfssljson -bare ca-certificate-manager

# az keyvault secret set --name ""

# az keyvault certificate download --file
#                                  [--encoding {DER, PEM}]
#                                  [--id]
#                                  [--name]
#                                  [--subscription]
#                                  [--vault-name]
#                                  [--version]

#az keyvault certificate download --vault-name cloudruler -n cloudruler-io -f cloudruler-io.pem && \
#openssl x509 -in cert.pem -inform PEM  -noout -sha1 -fingerprint
echo "Create root.pfx"
openssl pkcs12 -export -passout file:password -out root.pfx -inkey root-key.pem -in root.pem
echo "Upload root.pfx to key vault"
az keyvault certificate import --vault-name cloudruler --name root --file root.pfx --password $(cat password)

openssl x509 -in root.pem -text -noout

for instance in ca-kubernetes ca-kubernetes-front-proxy ca-etcd ca-certificate-manager; do
echo "Create ${instance}-chain.pem"
cat ${instance}.pem root.pem > ${instance}-chain.pem
echo "Create ${instance}.pfx"
openssl pkcs12 -export -passout file:password -out ${instance}.pfx -inkey ${instance}-key.pem -in ${instance}-chain.pem
echo "Upload ${instance}.pfx to key vault"
az keyvault certificate import --vault-name cloudruler --name ${instance} --file ${instance}.pfx --password $(cat password)
done

#Calculate the hash which we can pass to kubeadm join
CA_HASH=$(openssl x509 -pubkey -in ./ca-kubernetes.pem | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
echo "sha256:$CA_HASH" | tee discovery-token-ca-cert-hash
az keyvault secret set --vault-name cloudruler --name k8s-discovery-token-ca-cert-hash --file discovery-token-ca-cert-hash --description="The hash calculated from ca-kubernetes.pem which we can pass to kubeadm join"

#Generate the service account token
cat > openssl.cnf << EOF
[ req ]
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req_client ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

echo "Create sa.key"
openssl ecparam -name secp521r1 -genkey -noout -out sa.key
echo "Create sa.pub"
openssl ec -in sa.key -outform PEM -pubout -out sa.pub
chmod 0600 sa.key
echo "Create sa.crt"
openssl req -new -sha256 -key sa.key -subj "/CN=system:kube-controller-manager" \
  | openssl x509 -req -sha256 -CA root.pem -CAkey root-key.pem -CAcreateserial -out sa.crt -days 3650 -extensions v3_req_client -extfile ./openssl.cnf

echo "Create sa.pfx"
openssl pkcs12 -export -out sa.pfx -inkey sa.key -in sa.crt
echo "Upload sa.pfx to key vault"
az keyvault certificate import --vault-name cloudruler --name sa --file sa.pfx


# for instance in root ca-kubernetes ca-kubernetes-front-proxy ca-etcd ca-certificate-manager; do
# openssl pkcs12 -export -passout file:password -out ${instance}.pfx -inkey ${instance}-key.pem -in ${instance}.pem
# az keyvault certificate download --vault-name cloudruler --name ${instance} --file ${instance}.pem --password $(cat password)
# done

# openssl pkcs12 -export -passout file:password -out ca-kubernetes.pfx -inkey ca-kubernetes-key.pem -in ca-kubernetes.pem
# openssl pkcs12 -export -passout file:password -out ca-kubernetes-front-proxy.pfx -inkey ca-kubernetes-front-proxy-key.pem -in ca-kubernetes-front-proxy.pem
# openssl pkcs12 -export -passout file:password -out ca-etcd.pfx -inkey ca-etcd-key.pem -in ca-etcd.pem
# openssl pkcs12 -export -passout file:password -out ca-certificate-manager.pfx -inkey ca-certificate-manager-key.pem -in ca-certificate-manager.pem
