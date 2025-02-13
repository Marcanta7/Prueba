module "data_generator" {
  source         = "./Data_Generator"
  project_id     = var.project_id
  region         = var.region
}

module "dataflow" {
  source         = "./Dataflow"
  project_id     = var.project_id
  region         = var.region
  bucket_dataflow   = var.bucket_dataflow
}