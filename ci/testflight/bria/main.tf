variable "testflight_namespace" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  smoketest_namespace  = "galoy-staging-smoketest"
  bitcoin_namespace    = "galoy-staging-bitcoin"
  testflight_namespace = var.testflight_namespace

}

resource "kubernetes_namespace" "testflight" {
  metadata {
    name = local.testflight_namespace
  }
}

resource "random_password" "postgresql" {
  length  = 20
  special = false
}

resource "random_id" "signer_encryption_key" {
  byte_length = 32
}

resource "kubernetes_secret" "bria" {
  metadata {
    name      = "bria"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = {
    pg-user-pw : random_password.postgresql.result
    pg-con : "postgres://bria:${random_password.postgresql.result}@bria-postgresql:5432/bria"
    signer-encryption-key : random_id.signer_encryption_key.hex
  }
}

resource "helm_release" "bria" {
  name      = "bria"
  chart     = "${path.module}/chart"
  namespace = kubernetes_namespace.testflight.metadata[0].name

  values = [
    templatefile("${path.module}/testflight-values.yml.tmpl", {
      bitcoin_namespace : local.bitcoin_namespace
    })
  ]

  depends_on = [kubernetes_secret.bria]

  dependency_update = true
}

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = local.testflight_namespace
    namespace = local.smoketest_namespace
  }
  data = {}
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
