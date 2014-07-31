#!/bin/bash

if [ ! -d node_modules/x509-keygen ]; then
    npm -l install x509-keygen
fi

node <<EOF
require('x509-keygen').x509_keygen({ subject    : '/CN=TAAS-proxy'
                                   , keyfile    : 'proxy.key'
                                   , certfile   : 'proxy.crt'
                                   , sha1file   : 'proxy.sha1'
                                   , alternates : [ 'IP:127.0.0.1' ]
                                   , destroy    : false }, function(err, data) {
  if (err) return console.log('keypair generation error: ' + err.message);

  console.log('keypair generated.');
});
EOF

cat proxy.key proxy.crt > proxy.pem
openssl pkcs12 -export -name TAAS-proxy -in proxy.pem -out proxy.p12 -passout 'pass:'
openssl x509   -inform pem -outform der -in proxy.crt -out proxy.cer

rm -f proxy.crt proxy.key proxy.pem proxy.sha1
