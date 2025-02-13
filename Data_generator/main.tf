resource "google_artifact_registry_repository" "repo" {
  provider      = google
  project       = var.project_id
  location      = var.region
  repository_id = "volunteer-matching-repo"
  format        = "DOCKER"
}





resource "google_cloudbuild_trigger" "build_trigger" {
  name     = "build-trigger"
  location = "global"

  # Configuración del repositorio y rama
  trigger_template {
    branch_name = "main"
    repo_name   = "Prueba"
  }

  # Información de la cuenta de servicio para ejecutar el trigger
  service_account = google_service_account.cloudbuild_service_account.id

  # Archivo de configuración de Cloud Build
  filename = "cloudbuild.yaml"

  build {
    # Definir los pasos del build
    step {
      name   = "gcr.io/cloud-builders/gsutil"
      args   = ["cp", "gs://mybucket/remotefile.zip", "localfile.zip"]
      timeout = "120s"
      secret_env = ["MY_SECRET"]
    }

    step {
      name   = "ubuntu"
      script = "echo hello"
    }

    # Fuentes de los archivos para el build
    source {
      storage_source {
        bucket = "mybucket"
        object = "source_code.tar.gz"
      }
    }

    # Etiquetas y variables de sustitución
    tags = ["build", "newFeature"]
    substitutions = {
      _FOO = "bar"
      _BAZ = "qux"
    }

    queue_ttl = "20s"
    logs_bucket = "gs://mybucket/logs"

    secret {
      kms_key_name = "projects/myProject/locations/global/keyRings/keyring-name/cryptoKeys/key-name"
      secret_env = {
        PASSWORD = "ZW5jcnlwdGVkLXBhc3N3b3JkCg=="
      }
    }

    available_secrets {
      secret_manager {
        env          = "MY_SECRET"
        version_name = "projects/myProject/secrets/mySecret/versions/latest"
      }
    }

    artifacts {
      images = ["gcr.io/$PROJECT_ID/$REPO_NAME:$COMMIT_SHA"]
      objects {
        location = "gs://bucket/path/to/somewhere/"
        paths = ["path"]
      }
    }
  }

  # Permitir logs de build
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
}

# Crear la cuenta de servicio para Cloud Build
resource "google_service_account" "cloudbuild_service_account" {
  account_id = "cloud-sa"
}

# Asignar el rol de servicio para la cuenta de servicio de Cloud Build
resource "google_project_iam_member" "act_as" {
  project = data.google_project.project.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

# Asignar el rol de escritor de logs a la cuenta de servicio
resource "google_project_iam_member" "logs_writer" {
  project = data.google_project.project.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}



resource "google_pubsub_topic" "volunteers" {
  name    = "volunteers"
  project = var.project_id
}

resource "google_pubsub_topic" "affected" {
  name    = "affected"
  project = var.project_id
}





resource "google_cloud_run_service" "generator" {
  name     = "volunteer-generator"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = "europe-west1-docker.pkg.dev/${var.project_id}/volunteer-matching-repo/generator:latest"
        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.repo,
    google_cloudbuild_trigger.build_trigger
  ]
}




variable "project_id" {
  description = "El ID del proyecto"
  type        = string
}

variable "region" {
  description = "La región de despliegue"
  type        = string
}