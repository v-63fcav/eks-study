# ps-sl

> Plataforma base em AWS com EKS, observabilidade e automação de deploy via GitHub Actions.

[![Terraform Deployment](https://github.com/v-63fcav/ps-sl/actions/workflows/tf-deploy.yml/badge.svg)](https://github.com/v-63fcav/ps-sl/actions/workflows/tf-deploy.yml)
![Terraform](https://img.shields.io/badge/Terraform-%3E%3D0.12-7B42BC?logo=terraform)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32-326CE5?logo=kubernetes)
![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)

---

## Sumário

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Pré-Requisitos](#pré-requisitos)
- [Backend de State](#backend-de-state)
- [Fluxo de Deploy](#fluxo-de-deploy)
- [Automação com GitHub Actions](#automação-com-github-actions)
- [Observabilidade](#observabilidade)
- [Acesso ao Ambiente](#acesso-ao-ambiente)
- [Variáveis e Outputs](#variáveis-e-outputs)
- [Decisões Técnicas](#decisões-técnicas)
- [Limitações Conhecidas](#limitações-conhecidas)
- [Próximos Refinamentos](#próximos-refinamentos)

---

## Visão Geral

Este repositório implementa uma plataforma base em AWS com foco em provisionamento declarativo e observabilidade em Kubernetes. A solução está dividida em duas camadas independentes de Terraform:

| Camada | Diretório | Responsabilidade |
|---|---|---|
| Infraestrutura | `infra/` | Rede (VPC), segurança e cluster Amazon EKS |
| Aplicações | `apps/` | Componentes operacionais instalados via Helm |

O ciclo de entrega é totalmente automatizado por GitHub Actions, com pipelines dedicados para provisionamento e destruição.

---

## Arquitetura

### Camada de Infraestrutura (`infra/`)

| Componente | Implementação |
|---|---|
| Backend Terraform | State remoto em S3 (`ps-sl-state-bucket-cavi-2`) |
| Região | `us-east-2` |
| Rede | VPC com CIDR `10.0.0.0/16` |
| Subnets privadas | `10.0.1.0/24`, `10.0.2.0/24` |
| Subnets públicas | `10.0.4.0/24`, `10.0.5.0/24` |
| Saída para internet | Internet Gateway + NAT Gateway único |
| Cluster | Amazon EKS `1.32` via módulo oficial `terraform-aws-modules/eks/aws` |
| Node group | mínimo 2 / desejado 2 / máximo 6 nós do tipo `t3.medium` |
| IRSA | Habilitado — autenticação segura entre workloads e AWS sem credenciais estáticas |
| Segurança | Security group dedicado para comunicação dos worker nodes |

### Camada de Aplicações (`apps/`)

| Componente | Chart Helm | Finalidade |
|---|---|---|
| AWS Load Balancer Controller | Chart oficial da AWS | Exposição de Ingresses e ALBs no EKS |
| kube-prometheus-stack | Chart da comunidade Prometheus | Métricas, alertas, Prometheus e Grafana |
| Blackbox Exporter | Chart da comunidade Prometheus | Sondas ICMP para monitoramento de conectividade |

> O provider Kubernetes/Helm utiliza autenticação dinâmica via `aws eks get-token`. A execução local requer credenciais AWS válidas com acesso ao cluster.

---

## Estrutura do Repositório

```text
ps-sl/
├── .github/workflows/
│   ├── tf-deploy.yml       # Pipeline de provisionamento (push para main)
│   └── tf-destroy.yml      # Pipeline de destruição (execução manual)
├── infra/
│   ├── backend.tf
│   ├── eks-cluster.tf
│   ├── iam.tf
│   ├── iam_policy.json
│   ├── outputs.tf
│   ├── sg.tf
│   ├── variables.tf
│   ├── versions.tf
│   └── vpc.tf
├── apps/
│   ├── alb.tf
│   ├── backend.tf
│   ├── helm.tf
│   ├── providers.tf
│   ├── values-blackbox.yaml
│   ├── values-prometheus.yaml
│   ├── variables.tf
│   └── versions.tf
└── README.md
```

---

## Pré-Requisitos

### Execução Local

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 0.12`
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) instalada e autenticada
- Permissões AWS para: VPC, EKS, IAM, ELB e acesso de leitura/escrita ao bucket de state
- `kubectl` (opcional) — para validações e inspeção pós-deploy
- Conectividade com o endpoint da API do EKS

### Execução via GitHub Actions

Configure os seguintes secrets no repositório:

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key da conta AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret key da conta AWS |
| `TF_API_TOKEN` | Token de autenticação no Terraform Cloud/HCP |

---

## Backend de State

O projeto utiliza backend remoto em S3 com states separados por camada, reduzindo acoplamento entre infraestrutura base e workloads:

| Camada | Bucket | Chave do state |
|---|---|---|
| `infra` | `ps-sl-state-bucket-cavi-2` | `terraform.tfstate` |
| `apps` | `ps-sl-state-bucket-cavi-2` | `terraform-apps.tfstate` |

---

## Fluxo de Deploy

### 1. Infraestrutura

A camada `infra/` provisiona VPC, subnets, NAT Gateway, cluster EKS, node group, OIDC provider e a role IRSA para o AWS Load Balancer Controller.

```bash
cd infra
terraform init
terraform validate
terraform plan
terraform apply
```

Outputs gerados ao final dessa fase:

| Output | Descrição |
|---|---|
| `cluster_name` | Nome do cluster EKS |
| `cluster_endpoint` | Endpoint da control plane |
| `cluster_ca` | Certificado CA do cluster (base64) |
| `alb_irsa_role` | ARN da role IRSA para o ALB Controller |

### 2. Aplicações

A camada `apps/` consome os outputs da fase anterior para instalar os charts Helm no cluster.

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

---

## Automação com GitHub Actions

### Pipeline de Deploy (`tf-deploy.yml`)

Acionado automaticamente em `push` para a branch `main`. Executa em duas etapas sequenciais:

1. **Job `infra`** — `init` → `validate` → `plan` → `apply` da camada de infraestrutura; exporta os outputs como variáveis do workflow.
2. **Job `apps`** — `init` → `validate` → `plan` → `apply` da camada de aplicações, injetando os outputs via `TF_VAR_*`.

### Pipeline de Destroy (`tf-destroy.yml`)

Acionado manualmente via `workflow_dispatch`. Executa `terraform destroy` na camada `infra` após `validate` e `plan`.

> **Atenção:** o processo de destruição atual cobre apenas a camada `infra`. Em cenários reais, remova primeiro a camada `apps` para evitar recursos órfãos (Load Balancers, Security Groups) que podem bloquear a remoção da infraestrutura base.

---

## Observabilidade

### Prometheus e Grafana

O chart `kube-prometheus-stack` está configurado com:

- Regras de alerta padrão habilitadas
- Grafana habilitado
- Retenção de métricas: `10d`
- Scrape interval global: `15s`
- Ingress com classe `alb` e anotações do AWS Load Balancer Controller (ALB internet-facing)

> **Segurança:** o Grafana é instalado com credenciais padrão (`admin` / `prom-operator`). **Altere a senha imediatamente após o primeiro acesso** em ambientes que não sejam de testes.

### Blackbox Exporter

Configurado com probe ICMP e capability `NET_RAW`, permitindo checagens de latência e disponibilidade entre nós do cluster.

### Job de Scraping: `node-to-node-latency`

Job adicional no Prometheus que utiliza o Blackbox Exporter para medir conectividade ICMP entre os nós — útil para identificar degradação de rede intra-cluster.

---

## Acesso ao Ambiente

Os endpoints publicados via ALB são **dinâmicos** e se alteram a cada recriação da infraestrutura. Para identificar o endereço atual após um deploy:

```bash
kubectl get ingress -A
```

Acesse o Grafana no endereço retornado, na porta 80 (HTTP). Faça login com as credenciais padrão e troque a senha imediatamente.

Para navegar diretamente para os dashboards de cluster:

```
http://<grafana-endpoint>/dashboards
```

---

## Variáveis e Outputs

### Variáveis — `infra/`

| Variável | Valor padrão | Descrição |
|---|---|---|
| `aws_region` | `us-east-2` | Região AWS do provisionamento |
| `vpc_cidr` | `10.0.0.0/16` | Faixa CIDR da VPC |
| `kubernetes_version` | `1.32` | Versão do cluster EKS |

### Variáveis — `apps/`

| Variável | Descrição |
|---|---|
| `cluster_name` | Nome do cluster EKS |
| `kube_host` | Endpoint da API do cluster |
| `kube_ca` | CA do cluster em base64 |
| `alb_irsa_role` | ARN da role IRSA para o ALB Controller |

### Outputs — `infra/`

| Output | Descrição |
|---|---|
| `cluster_id` | Identificador interno do cluster EKS |
| `cluster_name` | Nome final do cluster |
| `cluster_endpoint` | Endpoint da control plane |
| `cluster_ca` | Certificado da autoridade do cluster |
| `cluster_security_group_id` | Security group da control plane |
| `region` | Região AWS em uso |
| `oidc_provider_arn` | ARN do provider OIDC |
| `alb_irsa_role` | ARN da role IRSA para o ALB Controller |

---

## Decisões Técnicas

- **Separação `infra` / `apps`** — states independentes reduzem blast radius e permitem evoluir cada camada sem afetar a outra.
- **Módulos oficiais da comunidade** — uso de `terraform-aws-modules` para VPC, EKS e IAM garante boas práticas consolidadas e menor manutenção.
- **IRSA** — elimina o uso de credenciais AWS estáticas dentro do cluster; cada workload assume apenas a role de que necessita.
- **Helm via Terraform** — mantém o provisionamento de componentes operacionais no mesmo fluxo de IaC, sem ferramentas adicionais.
- **ALB internet-facing para Grafana** — simplifica o acesso externo inicial; pode ser evoluído para acesso privado ou com autenticação dedicada.

---

## Limitações Conhecidas

| # | Limitação |
|---|---|
| 1 | A camada `apps` recebe dados do cluster via outputs exportados pelo workflow — não lê o state remoto diretamente. |
| 2 | Não há persistência configurada para Prometheus e Grafana (sem PV/PVC); dados são perdidos ao reiniciar os pods. |
| 3 | O Ingress do Grafana não inclui TLS/SSL; tráfego trafega em HTTP. |
| 4 | O pipeline de destroy cobre apenas `infra`; a camada `apps` deve ser removida manualmente antes. |
| 5 | O processo de CD usa Terraform para instalação dos charts, sem abordagem GitOps dedicada. |

---

## Próximos Refinamentos

1. **Remote state na camada `apps`** — ler outputs da `infra` diretamente do state S3, eliminando acoplamento ao workflow.
2. **TLS/SSL** — adicionar suporte a certificados ACM no ALB Controller para HTTPS no Grafana e demais Ingresses.
3. **Persistência** — configurar PersistentVolumes (EBS) para Prometheus e Grafana.
4. **GitOps** — evoluir a entrega de aplicações com Argo CD ou Flux para ciclos de deploy mais seguros e auditáveis.
5. **Observabilidade avançada** — adicionar alertas, dashboards adicionais, políticas de retenção e integração com canais de notificação.
6. **Destroy completo** — criar workflow de destroy que remove `apps` antes de `infra`, evitando dependências remanescentes.
