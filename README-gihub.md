# ps-sl

## Visão Geral

Este repositório provisiona uma plataforma Kubernetes na AWS com foco em infraestrutura como código e observabilidade.

A solução está separada em duas camadas Terraform:

1. `infra/`: cria os recursos-base (VPC, EKS, IAM e segurança).
2. `apps/`: instala componentes de operação no cluster usando Helm.

O ciclo de deploy é automatizado por GitHub Actions.

## Objetivos da Solução

- usar Terraform como padrão declarativo de provisionamento;
- criar cluster EKS com nós em subnets privadas;
- habilitar exposição de serviços via AWS Load Balancer Controller;
- disponibilizar stack de observabilidade com Prometheus, Grafana e Blackbox Exporter;
- automatizar provisionamento e teardown via workflows CI/CD.

## Arquitetura

### Camada de Infraestrutura (`infra/`)

Recursos principais:

- backend remoto em S3 para estado Terraform;
- VPC com CIDR `10.0.0.0/16`;
- 2 subnets privadas + 2 subnets públicas;
- Internet Gateway + NAT Gateway;
- EKS com `enable_irsa = true`;
- node group gerenciado com instâncias `t3.medium`;
- role IRSA para o AWS Load Balancer Controller;
- security group para comunicação dos workers.

### Camada de Aplicações (`apps/`)

Componentes instalados via `helm_release`:

- `aws-load-balancer-controller`;
- `kube-prometheus-stack` (Prometheus + Grafana);
- `prometheus-blackbox-exporter`.

O provider Kubernetes/Helm autentica no cluster via `aws eks get-token`.

## Estrutura do Repositório

```text
ps-sl/
|-- .github/workflows/
|   |-- tf-deploy.yml
|   `-- tf-destroy.yml
|-- infra/
|   |-- backend.tf
|   |-- eks-cluster.tf
|   |-- iam.tf
|   |-- iam_policy.json
|   |-- outputs.tf
|   |-- sg.tf
|   |-- variables.tf
|   |-- versions.tf
|   `-- vpc.tf
|-- apps/
|   |-- alb.tf
|   |-- backend.tf
|   |-- helm.tf
|   |-- providers.tf
|   |-- values-blackbox.yaml
|   |-- values-prometheus.yaml
|   |-- variables.tf
|   `-- versions.tf
`-- README.md
```

## Pré-Requisitos

Para execução local:

- Terraform;
- AWS CLI autenticada;
- permissões AWS para VPC, EKS, IAM, ELB e S3;
- acesso ao bucket de state remoto;
- `kubectl` (recomendado para validações pós-deploy).

Para execução via GitHub Actions:

- `AWS_ACCESS_KEY_ID`;
- `AWS_SECRET_ACCESS_KEY`;
- `TF_API_TOKEN`.

## Backend Terraform

| Camada | Bucket | Key |
| --- | --- | --- |
| Infra | `ps-sl-state-bucket-cavi-2` | `terraform.tfstate` |
| Apps | `ps-sl-state-bucket-cavi-2` | `terraform-apps.tfstate` |

## Fluxo de Deploy

### 1. Infra

```bash
cd infra
terraform init
terraform validate
terraform plan
terraform apply
```

Outputs mais importantes:

- `cluster_name`
- `cluster_endpoint`
- `cluster_ca`
- `alb_irsa_role`

### 2. Apps

```bash
cd apps
terraform init
terraform validate
terraform plan \
  -var="cluster_name=<cluster_name>" \
  -var="kube_host=<cluster_endpoint>" \
  -var="kube_ca=<cluster_ca>" \
  -var="alb_irsa_role=<alb_irsa_role>"

terraform apply \
  -var="cluster_name=<cluster_name>" \
  -var="kube_host=<cluster_endpoint>" \
  -var="kube_ca=<cluster_ca>" \
  -var="alb_irsa_role=<alb_irsa_role>"
```

## GitHub Actions

### Deploy (`tf-deploy.yml`)

Executa em push na branch `main`:

1. aplica `infra`;
2. exporta outputs do Terraform;
3. aplica `apps` usando variáveis `TF_VAR_*` derivadas dos outputs.

### Destroy (`tf-destroy.yml`)

Executa manualmente (`workflow_dispatch`) e faz destroy da camada `infra`.

Recomendação operacional: destruir primeiro `apps` e depois `infra` para evitar dependências remanescentes no cluster.

## Observabilidade

### Prometheus + Grafana

Configurações relevantes em `values-prometheus.yaml`:

- retention: `10d`;
- scrape interval: `15s`;
- Grafana habilitado e publicado via Ingress classe `alb`.

### Blackbox Exporter

Configuração de probe ICMP para monitorar conectividade e latência entre nós.

### Scrape adicional

Job `node-to-node-latency` coleta métricas ICMP através do serviço `blackbox-exporter.monitoring.svc.cluster.local:9115`.

## Acesso ao Grafana

Exemplo de endpoint de referência:

- URL: `http://k8s-promethe-promethe-ec377d1cb1-1466923787.us-east-2.elb.amazonaws.com/dashboards`
- usuário: `admin`
- senha: `prom-operator`

Dashboard solicitado (exemplo):

- `http://k8s-promethe-promethe-ec377d1cb1-1466923787.us-east-2.elb.amazonaws.com/d/4XuMd2Iiz/kubernetes-eks-cluster-prometheus?orgId=1&from=1772564895528&to=1772566695528`

Para descobrir o endpoint atual após novo deploy:

```bash
kubectl get ingress -A
```

## Variáveis e Outputs

### Variáveis (`infra/variables.tf`)

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `aws_region` | `us-east-2` | Região AWS |
| `vpc_cidr` | `10.0.0.0/16` | CIDR da VPC |
| `kubernetes_version` | `1.32` | Versão do cluster |

### Variáveis (`apps/variables.tf`)

| Variável | Descrição |
| --- | --- |
| `cluster_name` | Nome do cluster EKS |
| `kube_host` | Endpoint da API do EKS |
| `kube_ca` | Certificado CA do cluster (base64) |
| `alb_irsa_role` | ARN da role IRSA do ALB controller |

### Outputs (`infra/outputs.tf`)

| Output | Descrição |
| --- | --- |
| `cluster_id` | ID do cluster EKS |
| `cluster_name` | Nome do cluster |
| `cluster_endpoint` | Endpoint da control plane |
| `cluster_ca` | Certificado CA |
| `cluster_security_group_id` | SG da control plane |
| `region` | Região utilizada |
| `oidc_provider_arn` | ARN do provider OIDC |
| `alb_irsa_role` | ARN da role IRSA |

## Limitações Atuais

- camada `apps` recebe dados por outputs do workflow, sem leitura direta de remote state;
- ausência de PV/PVC para persistência de Prometheus e Grafana;
- ausência de TLS/SSL completo no Ingress do Grafana;
- deploy de charts ainda acoplado ao Terraform, sem engine GitOps dedicada.

## Melhorias Recomendadas

1. Ler valores da camada `infra` diretamente com `terraform_remote_state`.
2. Implementar TLS com ACM no ALB.
3. Configurar persistência de dados para Prometheus/Grafana.
4. Evoluir para GitOps com Argo CD (ou equivalente).
5. Expandir alertas, dashboards e políticas de retenção.
