package main

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go/service/cloudfront/sign"
)

func main() {
	// This should use the Vault SDK to get it from vault
	priv, err := os.ReadFile("private_key.pem")
	if err != nil {
		log.Fatalf("Failed to read private key: %s\n", err.Error())
		return
	}

	// Turn .pem file into *rsa.PrivateKey
	privPem, _ := pem.Decode(priv)
	privPemBytes := privPem.Bytes
	var parsedKey interface{}
	parsedKey, err = x509.ParsePKCS8PrivateKey(privPemBytes)
	if err != nil {
		log.Fatalf("Failed to parse Key: %s\n", err.Error())
		return
	}
	var privateKey *rsa.PrivateKey
	var ok bool
	privateKey, ok = parsedKey.(*rsa.PrivateKey)
	if !ok {
		log.Print("Unable to parse RSA private key")
		return
	}

	// Generate Signed URL 1 hour duration
	distributionDomainName := "https://d29rocx8hatacz.cloudfront.net"
	filePath := "I_HAVE_PEAKED.png"
	rawURL := distributionDomainName + "/" + filePath
	// Public Key ID
	signer := sign.NewURLSigner("K28GN3KRV70S0T", privateKey)
	signedURL, err := signer.Sign(rawURL, time.Now().Add(1*time.Hour))
	if err != nil {
		log.Fatalf("Failed to sign url, err: %s\n", err.Error())
		return
	}
	fmt.Print(signedURL + "\n")
}
