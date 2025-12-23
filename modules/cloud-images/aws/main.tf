locals {
  cloud_images_url  = "https://github.com/siderolabs/talos/releases/download/${var.talos_version}/cloud-images.json"
  cloud_images_json = jsondecode(data.http.this.response_body)
  cloud_images_parsed = [
    for image in local.cloud_images_json :
    image.id
    if image.arch == var.arch && image.region == var.region
  ]
}

data "http" "this" {
  url = local.cloud_images_url

  request_headers = {
    Accept = "application/json"
  }
}
