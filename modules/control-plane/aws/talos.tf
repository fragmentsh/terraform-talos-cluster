# Talos machine configuration and cluster bootstrap

# -----------------------------------------------------------------------------
# Talos Machine Secrets
# -----------------------------------------------------------------------------

resource "talos_machine_secrets" "talos" {
  talos_version = var.talos_version
}

# -----------------------------------------------------------------------------
# Talos Machine Configuration for Control Plane
# -----------------------------------------------------------------------------

data "talos_machine_configuration" "control_plane" {
  for_each = local.control_plane_nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${aws_lb.control_plane.dns_name}:6443"
  machine_type       = "controlplane"
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  machine_secrets    = talos_machine_secrets.talos.machine_secrets

  config_patches = concat(
    [
      yamlencode({
        machine = {
          certSANs = [
            aws_lb.control_plane.dns_name
          ]
          network = {
            kubespan = {
              enabled = true
            }
          }
          kubelet = {
            registerWithFQDN = true
            extraArgs = {
              cloud-provider             = "external"
              rotate-server-certificates = true
            }
          }
          features = {
            kubernetesTalosAPIAccess = {
              enabled = true
              allowedRoles = [
                "os:reader"
              ]
              allowedKubernetesNamespaces = [
                "kube-system"
              ]
            }
          }
        }
        cluster = {
          discovery = {
            enabled = true
          }
          network = {
            cni = {
              name = "none"
            }
          }
          externalCloudProvider = {
            enabled = true
            manifests = [
              "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/main/docs/deploy/cloud-controller-manager.yml"
            ]
          }
          proxy = {
            disabled = true
          }
          extraManifests = [
            "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml"
          ]
        }
      })
    ],
    var.irsa.enabled ? [
      yamlencode({
        cluster = {
          apiServer = {
            extraArgs = {
              service-account-issuer = "https://${module.irsa_s3_bucket[0].s3_bucket_bucket_domain_name}"
            }
          }
          serviceAccount = {
            key = base64encode(tls_private_key.irsa_oidc[0].private_key_pem)
          }
        }
      })
    ] : [],
    each.value.config_patches
  )
}

# -----------------------------------------------------------------------------
# Talos Machine Bootstrap
# -----------------------------------------------------------------------------

resource "talos_machine_bootstrap" "talos" {
  depends_on = [
    aws_autoscaling_group.control_plane,
    aws_lb.control_plane
  ]

  node                 = aws_lb.control_plane.dns_name
  client_configuration = talos_machine_secrets.talos.client_configuration

  lifecycle {
    ignore_changes = [node]
  }
}

# -----------------------------------------------------------------------------
# Talos Cluster Kubeconfig
# -----------------------------------------------------------------------------

resource "talos_cluster_kubeconfig" "talos" {
  depends_on = [
    talos_machine_bootstrap.talos
  ]

  client_configuration = talos_machine_secrets.talos.client_configuration
  node                 = aws_lb.control_plane.dns_name
}

resource "talos_machine_configuration_apply" "control_plane" {
  depends_on = [talos_machine_bootstrap.talos]
  for_each   = local.control_plane_nodes

  client_configuration        = talos_machine_secrets.talos.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  node                        = data.aws_instance.control_plane[each.key].public_ip
  endpoint                    = aws_lb.control_plane.dns_name
}
