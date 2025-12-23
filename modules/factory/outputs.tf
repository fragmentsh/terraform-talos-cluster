output "talos_image" {
  value = {
    gcp = var.image_upload_platform == "gcp" ? {
      id        = google_compute_image.this[0].id
      self_link = google_compute_image.this[0].self_link
    } : {}
  }
}
