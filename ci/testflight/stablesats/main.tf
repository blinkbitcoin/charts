variable "testflight_namespace" {}
variable "okex_secret_key" {}
variable "okex_passphrase" {}
variable "okex_api_key" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  smoketest_namespace  = "galoy-staging-smoketest"
  galoy_namespace      = "galoy-staging-galoy"
  bitcoin_namespace    = "galoy-staging-bitcoin"
  testflight_namespace = var.testflight_namespace
}

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = local.testflight_namespace
    namespace = local.smoketest_namespace
  }
  data = {
    price_server_grpc_host = "stablesats-price.${local.testflight_namespace}.svc.cluster.local"
    price_server_grpc_port = 3325
  }
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

data "kubernetes_secret" "dealer_creds" {
  metadata {
    name      = "dealer-creds"
    namespace = local.galoy_namespace
  }
}

data "kubernetes_secret" "bria_credentials" {
  metadata {
    name      = "stablesats-bria-creds"
    namespace = local.bitcoin_namespace
  }
}

resource "kubernetes_secret" "stablesats" {
  metadata {
    name      = "stablesats"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = {
    pg-user-pw : random_password.postgresql.result
    pg-con : "postgres://stablesats:${random_password.postgresql.result}@stablesats-postgresql:5432/stablesats"
    okex-secret-key : var.okex_secret_key
    okex-passphrase : var.okex_passphrase
    galoy-phone-code : data.kubernetes_secret.dealer_creds.data["code"]
    dealer-api-key : data.kubernetes_secret.dealer_creds.data["dealer-api-key"]
    bria-profile-api-key : data.kubernetes_secret.bria_credentials.data["api-key"]
  }
}

resource "helm_release" "stablesats" {
  name      = "stablesats"
  chart     = "${path.module}/chart"
  namespace = kubernetes_namespace.testflight.metadata[0].name

  values = [
    templatefile("${path.module}/testflight-values.yml.tmpl", {
      galoy_phone_number : data.kubernetes_secret.dealer_creds.data["phone"]
      okex_api_key : var.okex_api_key
    })
  ]

  depends_on = [
    kubernetes_secret.stablesats,
  ]

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
