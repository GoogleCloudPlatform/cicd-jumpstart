# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_binary_authorization_policy" "policy" {
  project = module.project_service.project_id
  global_policy_evaluation_mode = "ENABLE"
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [
      //google_binary_authorization_attestor.built-by-cloud-build.id,
      //"projects/${var.project_hub_id}/attestors/built-by-cloud-build",
      google_binary_authorization_attestor.vulnz-attestor.id
    ]
  }

  cluster_admission_rules {
    cluster          = "${var.region}.${module.cluster-dev.name}"
    evaluation_mode  = "ALWAYS_ALLOW"
    enforcement_mode = "DRYRUN_AUDIT_LOG_ONLY"
  }
}
/*
resource "google_container_analysis_note_iam_member" "built-by-cloud-build-services" {
  project = var.project_hub_id
  note = "projects/${var.project_hub_id}/notes/built-by-cloud-build"
  role = "roles/containeranalysis.notes.occurrences.viewer"
  member = "serviceAccount:service-${data.google_project.hub.number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"
}

resource "google_container_analysis_note_iam_member" "built-by-cloud-build-hub" {
  project = var.project_hub_id
  note ="projects/${var.project_hub_id}/notes/built-by-cloud-build"
  role = "roles/containeranalysis.notes.occurrences.viewer"
  member = "serviceAccount:service-${data.google_project.service.number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"
}
*/
resource "google_container_analysis_note" "vulnz-attestor" {
  name    = "vulnz-attestor"
  project = var.project_hub_id
  attestation_authority {
    hint {
      human_readable_name = "Vulnerability Attestor"
    }
  }
}

resource "google_container_analysis_note_iam_member" "vulnz-attestor-services" {
  project = google_container_analysis_note.vulnz-attestor.project
  note = google_container_analysis_note.vulnz-attestor.name
  role = "roles/containeranalysis.notes.occurrences.viewer"
  member = "serviceAccount:service-${data.google_project.hub.number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"
}

resource "google_container_analysis_note_iam_member" "vulnz-attestor-hub" {
  project = google_container_analysis_note.vulnz-attestor.project
  note = google_container_analysis_note.vulnz-attestor.name
  role = "roles/containeranalysis.notes.occurrences.viewer"
  member = "serviceAccount:service-${data.google_project.service.number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"
}

resource "google_binary_authorization_attestor" "vulnz-attestor" {
  name    = "vulnz-attestor"
  project = var.project_hub_id
  attestation_authority_note {
    note_reference = google_container_analysis_note.vulnz-attestor.name
    public_keys {
      id = data.google_kms_crypto_key_version.vulnz-attestor.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.vulnz-attestor.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.vulnz-attestor.public_key[0].algorithm
      }
    }
  }
}
data "google_kms_crypto_key_version" "vulnz-attestor" {
  crypto_key = google_kms_crypto_key.vulnz-attestor-key.id
}

resource "google_kms_crypto_key_iam_member" "vulnz-attestor" {
  crypto_key_id = google_kms_crypto_key.vulnz-attestor-key.id
  role          = "roles/cloudkms.signer"
  member        = "serviceAccount:${var.sa-cb-email}"
}

resource "google_kms_crypto_key" "vulnz-attestor-key" {
  name     = "vulnz-attestor-key"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "RSA_SIGN_PKCS1_4096_SHA512"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_key_ring" "keyring" {
  project  = var.project_hub_id
  name     = "test-attestor-key-ring"
  location = "global"
}
