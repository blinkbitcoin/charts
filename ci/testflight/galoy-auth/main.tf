variable "testflight_namespace" {}

locals {
  cluster_name     = "galoy-staging-cluster"
  cluster_location = "us-east1"
  gcp_project      = "galoy-staging"

  smoketest_namespace  = "galoy-staging-smoketest"
  testflight_namespace = var.testflight_namespace

  session_keys = "session-keys"

  postgres_database = "auth_db"
  postgres_password = "postgres"
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
    kratos_admin_endpoint = "galoy-auth-kratos-admin.${local.testflight_namespace}.svc.cluster.local"
    kratos_admin_port     = 80
  }
}

resource "kubernetes_secret" "auth_backend" {
  metadata {
    name      = "auth-backend"
    namespace = local.testflight_namespace
  }
  data = {
    "session-keys" : local.session_keys
  }
}

resource "helm_release" "galoy_auth" {
  name       = "galoy-auth"
  chart      = "${path.module}/chart"
  repository = "https://blinkbitcoin.github.io/charts/"
  namespace  = kubernetes_namespace.testflight.metadata[0].name

  values = [
    templatefile("${path.module}/galoy-auth-testflight-values.yml.tmpl", {
      postgres_database : local.postgres_database
      postgres_password : local.postgres_password
    })
  ]

  dependency_update = true

  depends_on = [helm_release.postgres]
}

resource "helm_release" "postgres" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = kubernetes_namespace.testflight.metadata[0].name

  values = [
    templatefile("${path.module}/postgres-testflight-values.yml.tmpl", {
      postgres_database : local.postgres_database
      postgres_password : local.postgres_password
    })
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
