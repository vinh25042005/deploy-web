# ─── Remote Backend: GCS ───
# GCS có built-in state locking, không cần DynamoDB như AWS
# Object versioning giúp khôi phục state cũ nếu cần

terraform {
  backend "gcs" {
    bucket = "tfstate-techshop-56d0cbaa"
    prefix = "terraform/state"
  }
}
