locals {
  file_name = {
    gcp = "talos-${var.talos_version}-${var.talos_platform}-${var.talos_architecture}.tar.gz"
    aws = "talos-${var.talos_version}-${var.talos_platform}-${var.talos_architecture}.raw"
  }

  curl_command = {
    gcp = "curl -L -o ${path.module}/${local.file_name[var.image_upload_platform]} '${data.talos_image_factory_urls.this.urls.disk_image}'"
    aws = "curl -L '${data.talos_image_factory_urls.this.urls.disk_image}'| xz -d > ${path.module}/${local.file_name[var.image_upload_platform]}"
  }
}


data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
  platform      = var.talos_platform
  architecture  = var.talos_architecture
}

resource "terraform_data" "this" {
  triggers_replace = local.file_name
  provisioner "local-exec" {
    command = local.curl_command[var.image_upload_platform]
  }
}
