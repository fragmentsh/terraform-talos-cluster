output "ami_id" {
  value = one(local.cloud_images_parsed)
}
