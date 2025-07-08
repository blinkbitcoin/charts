variable "testflight_namespace" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  smoketest_namespace  = "galoy-staging-smoketest"
  bitcoin_namespace    = "galoy-staging-bitcoin"
  galoy_namespace      = "galoy-staging-galoy"
  testflight_namespace = var.testflight_namespace
}

resource "kubernetes_namespace" "testflight" {
  metadata {
    name = local.testflight_namespace
  }
}

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = local.testflight_namespace
    namespace = local.smoketest_namespace
  }
  data = {
    galoy_pay_endpoints  = jsonencode(["galoy-pay.${local.testflight_namespace}.svc.cluster.local"])
    galoy_pay_port       = 80
    lnurl_check_disabled = "true"
  }
}

resource "helm_release" "galoy_pay" {
  name      = "galoy-pay"
  chart     = "${path.module}/chart"
  namespace = kubernetes_namespace.testflight.metadata[0].name

  values = [
    file("${path.module}/testflight-values.yml")
  ]
}

resource "kubernetes_secret" "galoy_pay" {
  metadata {
    name      = "galoy-pay"
    namespace = local.testflight_namespace
  }

  data = {
    "next-auth-secret" : "dummy123"
    "client-secret" : "dummy"
  }
}

data "kubernetes_secret" "redis_creds" {
  metadata {
    name      = "galoy-redis-pw"
    namespace = local.galoy_namespace
  }
}
resource "kubernetes_secret" "redis_creds" {
  metadata {
    name      = "galoy-redis-pw"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = data.kubernetes_secret.redis_creds.data
}

resource "kubernetes_secret" "nostr_private_key" {
  metadata {
    name      = "galoy-nostr-private-key"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = {
    # random key
    "key" : "bb159f7aaafa75a7d4470307c9d6ea18409d4f082b41abcf6346aaae5b2b3b10"
  }
}

data "kubernetes_secret" "lnd1_credentials" {
  metadata {
    name      = "lnd1-credentials"
    namespace = local.bitcoin_namespace
  }
}

resource "kubernetes_secret" "lnd1_credentials" {
  metadata {
    name      = "lnd-credentials"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = data.kubernetes_secret.lnd1_credentials.data
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

provider "kubernetes-alpha" {
  host                   = "https://${data.google_container_cluster.primary.private_cluster_config.0.private_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  version = "~> 2.0"
  kubernetes {
    host                   = "https://${data.google_container_cluster.primary.private_cluster_config.0.private_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}
