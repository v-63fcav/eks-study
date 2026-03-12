# GP3 StorageClass with recommended configurations using in-tree EBS provider
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner = "kubernetes.io/aws-ebs"
  parameters = {
    type       = "gp3"
    encrypted  = "true"
    fsType     = "ext4"
  }

  allow_volume_expansion = true
  reclaim_policy         = "Retain"
  volume_binding_mode   = "WaitForFirstConsumer"
}
