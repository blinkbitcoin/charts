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

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = local.testflight_namespace
    namespace = local.smoketest_namespace
  }
  data = {
    blink_terminal_endpoint = "blink-terminal.${local.testflight_namespace}.svc.cluster.local"
    blink_terminal_port     = 3000
  }
}

resource "random_password" "postgresql" {
  length  = 20
  special = false
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "encryption_key" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "blink_terminal" {
  metadata {
    name      = "blink-terminal"
    namespace = local.testflight_namespace
  }

  data = {
    "database-url" : "postgres://blink_terminal:${random_password.postgresql.result}@blink-terminal-postgresql:5432/blink_terminal"
    "redis-password" : ""
    "jwt-secret" : random_password.jwt_secret.result
    "encryption-key" : random_password.encryption_key.result
    "network-encryption-key" : random_password.encryption_key.result
    "blinkpos-api-key" : "dummy"
    "blinkpos-btc-wallet-id" : "dummy"
    "blink-webhook-secret" : "dummy"
    "citrusrate-api-key" : "dummy"
    "pg-user-pw" : random_password.postgresql.result
  }
}

resource "helm_release" "blink_terminal" {
  name       = "blink-terminal"
  chart      = "${path.module}/chart"
  repository = "https://blinkbitcoin.github.io/charts/"
  namespace  = kubernetes_namespace.testflight.metadata[0].name

  values = [
    file("${path.module}/testflight-values.yml")
  ]

  depends_on = [kubernetes_secret.blink_terminal]

  dependency_update = true
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
