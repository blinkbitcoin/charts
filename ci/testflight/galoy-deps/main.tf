variable "testflight_namespace" {}
variable "smoketest_kubeconfig" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  testflight_namespace         = var.testflight_namespace
  smoketest_namespace          = "galoy-staging-smoketest"
  smoketest_kubeconfig         = var.smoketest_kubeconfig
  smoketest_name               = "smoketest"
  service_name                 = "${local.testflight_namespace}-ingress"
  jaeger_host                  = "galoy-deps-opentelemetry-collector"
  kubemonkey_fullname_override = local.testflight_namespace
}

resource "kubernetes_namespace" "testflight" {
  metadata {
    name = local.testflight_namespace
  }
}

resource "helm_release" "galoy_deps" {
  name      = "galoy-deps"
  chart     = "${path.module}/chart"
  namespace = kubernetes_namespace.testflight.metadata[0].name

  values = [
    templatefile("${path.module}/testflight-values.yml.tmpl", {
      service_name : local.service_name
      jaeger_host : local.jaeger_host
      kubemonkey_fullname_override : local.kubemonkey_fullname_override
    })
  ]

  dependency_update = true
}

resource "kubernetes_secret" "smoketest" {
  metadata {
    name      = local.testflight_namespace
    namespace = local.smoketest_namespace
  }
  data = {
    kafka_broker_endpoint = "kafka-kafka-brokers.${local.testflight_namespace}.svc.cluster.local"
    kafka_broker_port     = 9092
    smoketest_kubeconfig  = local.smoketest_kubeconfig
    smoketest_topic       = "${local.testflight_namespace}-smoketest"
    kafka_namespace       = local.testflight_namespace
  }
}

resource "kubernetes_role" "smoketest" {
  metadata {
    name      = local.smoketest_name
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "smoketest" {
  metadata {
    name      = local.smoketest_name
    namespace = kubernetes_namespace.testflight.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.smoketest.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.smoketest_name
    namespace = local.smoketest_namespace
  }
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
