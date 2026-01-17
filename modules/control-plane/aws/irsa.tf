resource "tls_private_key" "irsa" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}
