variable "testflight_namespace" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  smoketest_namespace  = "galoy-staging-smoketest"
  testflight_namespace = var.testflight_namespace

  service_name = "blink-lnurl-server"
  service_host = "${local.service_name}.${local.testflight_namespace}.svc.cluster.local"
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

resource "helm_release" "postgresql" {
  name       = "blink-lnurl-server-postgresql"
  chart      = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  namespace  = kubernetes_namespace.testflight.metadata[0].name

  values = [
    file("${path.module}/postgresql-values.yml")
  ]

  set {
    name  = "auth.password"
    value = random_password.postgresql.result
  }
}

resource "kubernetes_secret" "blink_lnurl_server" {
  metadata {
    name      = "blink-lnurl-server"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  data = {
    "db-url"        = "postgres://lnurl:${random_password.postgresql.result}@blink-lnurl-server-postgresql:5432/lnurl"
    "ssp-auth-seed" = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
}

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = local.testflight_namespace
    namespace = local.smoketest_namespace
  }
  data = {
    blink_lnurl_server_endpoint = local.service_host
    blink_lnurl_server_port     = 8080
  }
}

resource "helm_release" "blink_lnurl_server" {
  name      = local.service_name
  chart     = "${path.module}/chart"
  namespace = kubernetes_namespace.testflight.metadata[0].name

  values = [
    templatefile("${path.module}/testflight-values.yml", {
      service_host : local.service_host
    })
  ]

  depends_on = [
    helm_release.postgresql,
    kubernetes_secret.blink_lnurl_server,
  ]
}

data "google_container_cluster" "primary" {
  project  = local.gcp_project
  name     = local.cluster_name
  location = local.cluster_location
}

data "google_client_config" "default" {
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
    google = {
      source  = "hashicorp/google"
      version = "7.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
