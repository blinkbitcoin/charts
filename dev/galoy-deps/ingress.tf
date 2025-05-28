resource "kubernetes_manifest" "issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-issuer"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "dev@blink.sv"
        privateKeySecretRef = {
          name = "letsencrypt-issuer"
        }
        solvers = [
          { http01 = { ingress = { class = "nginx" } } }
        ]
      }
    }
  }

  depends_on = [
    helm_release.cert_manager
  ]
}
