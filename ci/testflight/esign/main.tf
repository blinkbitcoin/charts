variable "testflight_namespace" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"
  service_host     = "esign.${var.testflight_namespace}.svc.cluster.local"
}

resource "kubernetes_namespace" "testflight" {
  metadata {
    name = var.testflight_namespace
  }
}

resource "kubernetes_secret" "esign" {
  metadata {
    name      = "esign"
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }
  data = {}
}

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = var.testflight_namespace
    namespace = "galoy-staging-smoketest"
  }
  data = {
    esign_endpoint = "http://${local.service_host}:4100"
  }
}

resource "helm_release" "esign" {
  name      = "esign"
  chart     = "${path.module}/chart"
  namespace = kubernetes_namespace.testflight.metadata[0].name
  values = [yamlencode({
    env = {
      ESIGN_PROVIDER     = "mock"
      ESIGN_ENV          = "test"
      ALLOW_INSECURE_DEV = "true"
    }
  })]
  depends_on = [kubernetes_secret.esign]
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
  }
}
