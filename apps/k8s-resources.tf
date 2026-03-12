# GP3 StorageClass with recommended configurations
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner = "ebs.csi.aws.com"
  parameters = {
    type              = "gp3"
    encrypted         = "true"
    fsType            = "ext4"
    iops              = "3000"
    throughput        = "125"
    allowAutoIOPSPerGBIncrease = "true"
  }

  allow_volume_expansion = true
  reclaim_policy         = "Retain"
  volume_binding_mode   = "WaitForFirstConsumer"
}