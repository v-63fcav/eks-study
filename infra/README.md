# EKS Study — Infrastructure Layer

This directory contains all Terraform code that provisions the AWS foundation the cluster runs on. It must be applied **before** the `apps/` layer. Everything here is stateful cloud infrastructure — take care with destroys.

## What gets created

```
AWS Account
└── VPC (10.0.0.0/16)
    ├── Public subnets  [10.0.4.0/24, 10.0.5.0/24]  — ALB lives here
    │   └── Internet Gateway
    ├── Private subnets [10.0.1.0/24, 10.0.2.0/24]  — nodes live here
    │   └── NAT Gateway (single, in first AZ)
    └── EKS Cluster (ps-sl-eks-<random8>)
        ├── Managed Control Plane
        ├── Managed Node Group  (t3.medium × 2, scales to 6)
        ├── OIDC Identity Provider
        ├── EBS CSI Driver addon
        └── IAM
            ├── EBS CSI Driver Role   (IRSA)
            └── ALB Controller Role   (IRSA)
```

---

## Resources

### VPC — [vpc.tf](vpc.tf)

| Attribute | Value |
|---|---|
| Module | `terraform-aws-modules/vpc/aws` v5.7.0 |
| CIDR | `10.0.0.0/16` (configurable via `var.vpc_cidr`) |
| Public subnets | `10.0.4.0/24`, `10.0.5.0/24` |
| Private subnets | `10.0.1.0/24`, `10.0.2.0/24` |
| NAT Gateway | Single (cost-optimised; single point of failure for outbound) |
| DNS hostnames | Enabled — required for EKS and ALB |

**Subnet tagging** is critical for AWS Load Balancer Controller to discover where to place ALBs:

- Public subnets: `kubernetes.io/role/elb = 1` → internet-facing ALBs
- Private subnets: `kubernetes.io/role/internal-elb = 1` → internal ALBs
- Both: `kubernetes.io/cluster/<name> = shared` → cluster ownership

The cluster name includes a random 8-character suffix (`ps-sl-eks-<suffix>`) generated at apply time to avoid naming collisions across environments.

---

### Security Group — [sg.tf](sg.tf)

**`all_worker_mgmt`** — attached to all worker nodes via `eks_managed_node_group_defaults`.

| Direction | Protocol | Ports | Source/Dest |
|---|---|---|---|
| Ingress | All | All | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` |
| Egress | All | All | `0.0.0.0/0` |

Ingress allows all traffic from the three private RFC ranges — this covers VPC-internal traffic (pod-to-pod, control-plane-to-node) as well as any VPN or peered network in the standard private ranges. Egress is fully open so nodes can pull container images and reach AWS APIs.

> Note: The EKS module also creates its own cluster security group automatically. This SG is supplementary, added on top.

---

### EKS Cluster — [eks-cluster.tf](eks-cluster.tf)

**Module**: `terraform-aws-modules/eks/aws` v20.8.4

| Attribute | Value |
|---|---|
| Kubernetes version | 1.32 |
| Region | `us-east-2` |
| Control plane access | Public + Private endpoints |
| IRSA | Enabled (`enable_irsa = true`) |
| Node placement | Private subnets only |

#### Managed Node Group

| Attribute | Value |
|---|---|
| Instance type | `t3.medium` (2 vCPU, 4 GiB RAM) |
| AMI | `AL2_x86_64` (Amazon Linux 2) |
| Min / Desired / Max | 2 / 2 / 6 |
| Scaling | Manual only — no cluster autoscaler configured |

Nodes run in private subnets. Outbound internet access goes through the NAT Gateway for image pulls and AWS API calls. The control plane endpoints are both public (for `kubectl` from outside the VPC) and private (for node-to-plane communication within the VPC).

#### EKS Admin Access

`var.eks_admin_principal_arns` is a list of IAM principal ARNs that receive `AmazonEKSClusterAdminPolicy` scoped to the cluster. This is done via `aws_eks_access_entry` + `aws_eks_access_policy_association`, which uses the EKS Access Entries API (Kubernetes 1.23+) instead of the legacy `aws-auth` ConfigMap. Add your IAM user or role ARN here to get `kubectl` access without manual steps.

#### EBS CSI Driver Addon

The `aws-ebs-csi-driver` addon (v1.29.1-eksbuild.1) is installed as a managed EKS addon. It enables dynamic EBS volume provisioning for `PersistentVolumeClaims`. The addon runs with the `ebs_csi_driver_role` IRSA role (see IAM section). Without this addon, PVCs using the `ebs.csi.aws.com` provisioner would stay `Pending`.

> The `apps/` StorageClass uses the **in-tree** `kubernetes.io/aws-ebs` provisioner instead of `ebs.csi.aws.com` to avoid a known issue where PVCs can hang when the CSI driver pod is not yet scheduled. Both the addon and the in-tree driver are available — the in-tree one is used for reliability.

---

### IAM — [iam.tf](iam.tf)

Both IAM roles use **IRSA (IAM Roles for Service Accounts)** — no static credentials, no instance-profile-wide permissions. See the [OIDC explanation in the main README](../README.md) for how the token exchange works.

#### EBS CSI Driver Role

| Attribute | Value |
|---|---|
| Role name | `AmazonEKS_EBS_CSI_DriverRole` |
| Policy | AWS managed `AmazonEBSCSIDriverPolicy` |
| Trust scope | `kube-system:ebs-csi-controller-sa` only |
| Mechanism | `sts:AssumeRoleWithWebIdentity` via OIDC |

Allows the EBS CSI controller pod (and only that pod) to call `ec2:CreateVolume`, `ec2:AttachVolume`, `ec2:DeleteVolume`, etc. on behalf of PVC operations.

#### ALB Controller Role

| Attribute | Value |
|---|---|
| Role name | `eks-alb-controller` |
| Module | `terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks` v5.x |
| Policy | Custom policy from `iam_policy.json` (AWS-prescribed ALB controller policy) |
| Trust scope | `kube-system:aws-load-balancer-controller` only |

Allows the ALB controller pod to create and manage Application Load Balancers, target groups, listeners, and security group rules in response to Kubernetes `Ingress` resources. The role ARN is passed as a Terraform output to the `apps/` layer, which annotates the controller's service account with it.

---

### Outputs — [outputs.tf](outputs.tf)

The `apps/` layer reads these outputs via Terraform remote state:

| Output | Used by |
|---|---|
| `cluster_name` | `apps/` providers (helm, kubernetes) |
| `cluster_endpoint` | `apps/` providers |
| `cluster_ca` | `apps/` providers |
| `oidc_provider_arn` | Not consumed directly by apps (used within infra for IRSA) |
| `alb_irsa_role` | Injected into ALB controller values as service account annotation |
| `region` | `apps/` providers |

---

### Variables — [variables.tf](variables.tf)

| Variable | Default | Description |
|---|---|---|
| `kubernetes_version` | `1.32` | EKS control plane version |
| `vpc_cidr` | `10.0.0.0/16` | VPC address space |
| `aws_region` | `us-east-2` | Target AWS region |
| `eks_admin_principal_arns` | Two ARNs (Felipe + root) | IAM principals granted cluster admin |

To override, create a `terraform.tfvars` file or pass `-var` flags:
```hcl
# terraform.tfvars
aws_region               = "us-west-2"
eks_admin_principal_arns = ["arn:aws:iam::123456789012:user/you"]
```

---

## Deployment

```bash
cd infra
terraform init
terraform plan
terraform apply
```

After apply, configure `kubectl`:
```bash
aws eks update-kubeconfig \
  --region us-east-2 \
  --name $(terraform output -raw cluster_name)
```

Verify nodes are ready:
```bash
kubectl get nodes
```

Then proceed to `apps/`:
```bash
cd ../apps
terraform init
terraform apply
```

---

## Tear down

Destroy apps first (Helm releases create AWS resources like ALBs that must be cleaned up before the VPC can be deleted):
```bash
cd apps  && terraform destroy
cd ../infra && terraform destroy
```

Skipping the apps destroy first will leave orphaned ALBs and ENIs that block VPC deletion.
