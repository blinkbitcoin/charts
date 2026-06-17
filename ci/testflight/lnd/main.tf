variable "testflight_namespace" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  smoketest_namespace  = "galoy-staging-smoketest"
  testflight_namespace = var.testflight_namespace
}

resource "kubernetes_namespace" "testflight" {
  metadata {
    name = local.testflight_namespace
  }
}

data "kubernetes_secret" "bitcoin_rpcpassword" {
  metadata {
    name      = "bitcoind-rpcpassword"
    namespace = "galoy-staging-bitcoin"
  }
}

resource "kubernetes_secret" "bitcoinrpc_password" {
  metadata {
    name      = "bitcoind-rpcpassword"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = data.kubernetes_secret.bitcoin_rpcpassword.data
}

data "kubernetes_secret" "network" {
  metadata {
    name      = "network"
    namespace = "galoy-staging-bitcoin"
  }
}

resource "kubernetes_secret" "network" {
  metadata {
    name      = "network"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = data.kubernetes_secret.network.data
}

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = local.testflight_namespace
    namespace = local.smoketest_namespace
  }
  data = {
    lnd_api_endpoint = "lnd1.${local.testflight_namespace}.svc.cluster.local"
    lnd_p2p_endpoint = "lnd1-p2p.${local.testflight_namespace}.svc.cluster.local"
  }
}

resource "tls_private_key" "lnd" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "lnd1" {
  private_key_pem = tls_private_key.lnd.private_key_pem

  subject {
    common_name  = "localhost"
    organization = "org"
  }

  validity_period_hours = 420 * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [
    "localhost",
  ]
  ip_addresses = ["127.0.0.1", "0.0.0.0"]
}

resource "kubernetes_secret" "lnd1" {
  metadata {
    name      = "lnd1-tls"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = {
    "tls.cert" = tls_self_signed_cert.lnd1.cert_pem
    "tls.key"  = tls_private_key.lnd.private_key_pem
  }
}

resource "kubernetes_secret" "lnd_pg_pass" {
  metadata {
    name      = "lnd-postgres-creds"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = {
    uri                 = "postgres://lnd:lnd@lnd1-postgresql:5432/lnd"
    "postgres-password" = "lnd"
  }
}

resource "helm_release" "lnd1" {
  name       = "lnd1"
  chart      = "${path.module}/chart"
  repository = "https://blinkbitcoin.github.io/charts/"
  namespace  = kubernetes_namespace.testflight.metadata[0].name

  dependency_update = true
  timeout           = 800

  values = [
    file("${path.module}/testflight-values.yml")
  ]

  depends_on = [
    kubernetes_secret.bitcoinrpc_password
  ]
}

data "google_container_cluster" "primary" {
  project  = local.gcp_project
  name     = local.cluster_name
  location = local.cluster_location
}

data "google_client_config" "default" {
  provider = google-beta
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.private_cluster_config.0.private_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.primary.private_cluster_config.0.private_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}
