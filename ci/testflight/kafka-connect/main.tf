variable "testflight_namespace" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  kafka_namespace      = "galoy-staging-kafka"
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
    kafka_connect_api_host = "${local.testflight_namespace}-kafka-connect-api.${local.kafka_namespace}.svc.cluster.local"
    kafka_connect_api_port = 8083
  }
}

resource "helm_release" "kafka_connect" {
  name       = local.testflight_namespace
  chart      = "${path.module}/chart"
  repository = "https://blinkbitcoin.github.io/charts/"
  namespace  = local.kafka_namespace

  values = [
    templatefile("${path.module}/testflight-values.yml.tmpl", {
      kafka_connect_instance_name : "${local.testflight_namespace}-kafka",
    })
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
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "4.64.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "4.64.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}
