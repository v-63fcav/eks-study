# ps-sl - Plataforma de Observabilidade Kubernetes

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5?style=for-the-badge&logo=kubernetes)](https://kubernetes.io/)
[![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions)](https://github.com/features/actions)
[![Helm](https://img.shields.io/badge/Helm-3.0+-0F1689?style=for-the-badge&logo=helm)](https://helm.sh/)

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Componentes de Infraestrutura](#componentes-de-infraestrutura)
- [Componentes de Aplicação](#componentes-de-aplicação)
- [Deploy](#deploy)
- [Acesso e Credenciais](#acesso-e-credenciais)
- [Configuração](#configuração)
- [Solução de Problemas](#solução-de-problemas)
- [Roadmap](#roadmap)
- [Contribuindo](#contribuindo)
- [Licença](#licença)

---

## 🎯 Visão Geral

Este projeto implementa uma plataforma completa de observabilidade Kubernetes na AWS EKS utilizando as melhores práticas de Infraestrutura como Código (IaC). A solução utiliza Terraform para gerenciamento declarativo de infraestrutura, EKS para orquestração de contêineres e o stack Prometheus/Grafana para monitoramento e observabilidade abrangente.

### Funcionalidades Principais

- **Infraestrutura Declarativa**: Provisionamento de infraestrutura baseado em Terraform
- **Alta Disponibilidade**: Cluster EKS multi-AZ com node groups distribuídos
- **Observabilidade**: Stack integrado de monitoramento Prometheus e Grafana
- **CI/CD**: GitHub Actions para deployments automatizados
- **Ingress**: AWS Application Load Balancer Controller para gerenciamento de tráfego
- **Segurança**: Topologia de rede isolada com subnets privadas para workloads

---

## 🏗️ Arquitetura

### Arquitetura de Alto Nível

```
┌─────────────────────────────────────────────────────────────┐
│                        Região AWS                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                      VPC                                 │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │ Subnet Pública│  │ Subnet Pública│  │ Subnet Pública│ │ │
│  │  │   (AZ-1)      │  │   (AZ-2)      │  │   (AZ-3)      │ │ │
│  │  │   ┌─────┐    │  │   ┌─────┐    │  │   ┌─────┐    │ │ │
│  │  │   │ IGW │    │  │   │     │    │  │   │     │    │ │ │
│  │  │   └─────┘    │  │   └─────┘    │  │   └─────┘    │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │Subnet Privada│  │Subnet Privada│  │Subnet Privada│ │ │
│  │  │   (AZ-1)      │  │   (AZ-2)      │  │   (AZ-3)      │ │ │
│  │  │   ┌─────┐    │  │   ┌─────┐    │  │   ┌─────┐    │ │ │
│  │  │   │ NAT │    │  │   │ NAT │    │  │   │ NAT │    │ │ │
│  │  │   └─────┘    │  │   └─────┘    │  │   └─────┘    │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  │                                                       │ │
│  │  ┌─────────────────────────────────────────────────┐ │ │
│  │  │                Cluster EKS                        │ │ │
│  │  │  ┌────────────────────────────────────────────┐│ │ │
│  │  │  │          Control Plane (Gerenciado)        ││ │ │
│  │  │  └────────────────────────────────────────────┘│ │ │
│  │  │  ┌────────────────────────────────────────────┐│ │ │
│  │  │  │          Node Groups                       ││ │ │
│  │  │  │  ┌──────────────────────────────────────┐ ││ │ │
│  │  │  │  │         Worker Nodes                 │ ││ │ │
│  │  │  │  │  ┌────────────────────────────────┐ ││ │ │
│  │  │  │  │  │     ALB Ingress Controller     │ ││ │ │
│  │  │  │  │  └────────────────────────────────┘ ││ │ │
│  │  │  │  │  ┌────────────────────────────────┐ ││ │ │
│  │  │  │  │  │     Prometheus + Grafana       │ ││ │ │
│  │  │  │  │  └────────────────────────────────┘ ││ │ │
│  │  │  │  │  ┌────────────────────────────────┐ ││ │ │
│  │  │  │  │  │     Blackbox Exporter          │ ││ │ │
│  │  │  │  │  └────────────────────────────────┘ ││ │ │
│  │  │  │  └──────────────────────────────────────┘ ││ │ │
│  │  │  └────────────────────────────────────────────┘│ │ │
│  │  └─────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Fases de Deploy

A solução é implantada em duas fases distintas:

1. **Fase de Infraestrutura** (`infra/`): Infraestrutura base AWS
2. **Fase de Aplicações** (`apps/`): Aplicações Kubernetes e stack de monitoramento

---

## 📦 Pré-requisitos

Antes de implantar este projeto, certifique-se de ter o seguinte instalado:

### Ferramentas Necessárias

- **AWS CLI**: `>= 2.0`
- **Terraform**: `>= 1.0`
- **kubectl**: `>= 1.20`
- **Helm**: `>= 3.0`
- **Git**: Versão mais recente

### Requisitos AWS

- Conta AWS ativa com permissões apropriadas
- Credenciais da AWS CLI configuradas
- Quotas de serviço suficientes para:
  - Clusters EKS e node groups
  - VPC, subnets e recursos de rede
  - Load balancers

### Configuração GitHub

- Repositório GitHub com Actions habilitado
- Credenciais AWS configuradas como secrets do repositório
- Backend Terraform Cloud/Enterprise configurado

---

## 📁 Estrutura do Projeto

```
ps-sl/
├── infra/                    # Código Terraform de infraestrutura
│   ├── backend.tf           # Configuração do backend Terraform
│   ├── eks-cluster.tf       # Definição do cluster EKS
│   ├── iam.tf              # Roles e políticas IAM
│   ├── iam_policy.json     # Documento de política IAM
│   ├── outputs.tf          # Outputs da infraestrutura
│   ├── sg.tf              # Configurações de security groups
│   ├── variables.tf       # Variáveis de entrada
│   ├── versions.tf        # Versões dos providers
│   └── vpc.tf            # VPC e rede
├── apps/                     # Código Terraform de aplicações
│   ├── backend.tf         # Configuração do backend Terraform
│   ├── helm.tf           # Deployments de charts Helm
│   ├── k8s-resources.tf  # Recursos Kubernetes adicionais
│   ├── providers.tf      # Configurações dos providers
│   ├── variables.tf      # Variáveis de entrada
│   ├── versions.tf       # Versões dos providers
│   └── values/           # Arquivos de configuração Helm
│       ├── values-alb-controller.yaml   # Values do ALB controller
│       ├── values-blackbox.yaml         # Values do blackbox exporter
│       └── values-prometheus.yaml       # Values do stack Prometheus
├── .gitignore
├── .terraform.lock.hcl
└── README.md
```

---

## 🏢 Componentes de Infraestrutura

### Arquitetura de Rede

A infraestrutura implementa uma topologia de rede segura:

- **VPC**: VPC personalizada com bloco CIDR configurado via variáveis
- **Subnets Públicas**: 2 subnets com acesso ao Internet Gateway (IGW)
- **Subnets Privadas**: 2 subnets com NAT Gateway para acesso de saída à internet
- **Security Groups**: 
  - Security group do control plane com portas mínimas necessárias
  - Security group de worker nodes para comunicação do cluster
  - Security group do ALB controller para tráfego de ingress

### Recursos de Computação

- **Cluster EKS**: Control plane Kubernetes gerenciado
- **Node Groups**: 
  - Distribuídos em 2 Availability Zones
  - Auto-scaling habilitado
  - Colocação em subnets privadas para segurança aprimorada

### Configuração IAM

- **Role do Cluster EKS**: Permissões para gerenciamento do cluster
- **Role do Node Group**: Permissões para worker nodes
- **Política do ALB Controller**: Política personalizada para gerenciamento de load balancers
- **EKS Access Entry**: Configuração automática de acesso administrativo ao cluster via Terraform (executado após criação do cluster)

---

## 🚀 Componentes de Aplicação

### Stack de Monitoramento

#### Prometheus
- Banco de dados de séries temporais para coleta de métricas
- Service discovery para recursos Kubernetes
- Períodos de retenção configuráveis
- Capacidades de alerta (Alertmanager desabilitado para simplificar deployment)

#### Grafana
- Dashboard de visualização para métricas
- Dashboards pré-configurados para monitoramento EKS
- Suporte a dashboards personalizados
- Autenticação de usuário (admin/prom-operator)

#### Blackbox Exporter
- Monitoramento de endpoints externos
- Probes HTTP, HTTPS, ICMP e TCP
- Intervalos de probe configuráveis
- Integração com alertas do Prometheus

### Ingress Controller

- **AWS Load Balancer Controller**
  - Gerenciamento de recursos Ingress
  - Integração automática de certificados SSL/TLS
  - Integração Route 53 (melhoria futura)

---

## 🚦 Deploy

### Fase 1: Deploy de Infraestrutura

1. **Navegue para o diretório de infraestrutura**
   ```bash
   cd infra
   ```

2. **Inicialize o Terraform**
   ```bash
   terraform init
   ```

3. **Revise e personalize as variáveis**
   ```bash
   terraform plan
   ```

4. **Implante a infraestrutura**
   ```bash
   terraform apply
   ```

5. **Configure o kubectl**
   ```bash
   aws eks update-kubeconfig --region <região> --name <nome-do-cluster>
   ```

### Fase 2: Deploy de Aplicações

1. **Navegue para o diretório de aplicações**
   ```bash
   cd ../apps
   ```

2. **Inicialize o Terraform**
   ```bash
   terraform init
   ```

3. **Revise o plano de deploy**
   ```bash
   terraform plan
   ```

4. **Implante o stack de monitoramento**
   ```bash
   terraform apply
   ```

### GitHub Actions Deploy

O projeto utiliza GitHub Actions para CI/CD. Certifique-se de que os seguintes secrets estejam configurados no seu repositório:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `TF_API_TOKEN` (se usando Terraform Cloud/Enterprise)

O workflow irá:
1. Validar a configuração Terraform
2. Executar verificações de segurança
3. Aplicar mudanças na infraestrutura
4. Implantar aplicações

---

## 🔐 Acesso e Credenciais

### Dashboard Grafana

- **URL**: `http://<elb-dns-name>/dashboards`
- **Usuário**: `admin`
- **Senha**: `prom-operator`
- **Dashboard do Cluster EKS**: `http://<elb-dns-name>/d/4XuMd2Iiz/kubernetes-eks-cluster-prometheus`

> ⚠️ **Nota de Segurança**: Altere as credenciais padrão imediatamente após o primeiro deploy. Use AWS Secrets Manager ou secrets do Kubernetes para deployments em produção.

### Recursos AWS

Acesse o Console AWS para visualizar:
- Cluster EKS: `Amazon EKS > Clusters`
- Load Balancers: `EC2 > Load Balancers`
- VPC: `VPC > Your VPCs`

---

## ⚙️ Configuração

### Variáveis Terraform

Principais variáveis para configurar:

```hcl
# Infraestrutura (infra/variables.tf)
variable "aws_region" {
  description = "Região AWS para deploy"
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  default     = "ps-sl-cluster"
}

variable "eks_admin_principal_arn" {
  type        = string
  description = "IAM principal ARN para conceder acesso de administrador ao cluster EKS (ex: arn:aws:iam::123456789012:user/username)"
}
```

> **Nota**: O parâmetro `eks_admin_principal_arn` é obrigatório e configura automaticamente o acesso administrativo ao cluster EKS via Terraform, eliminando a necessidade de comandos manuais `aws eks create-access-entry` e `aws eks associate-access-policy`.

### Values Helm

Personalize as configurações do Prometheus e Grafana em `apps/values-prometheus.yaml`:

```yaml
prometheus:
  retention: 15d
  storageClass: gp2
  resources:
    requests:
      memory: "512Mi"
      cpu: "100m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### Configuração de Escala

Modifique o scaling do node group em `infra/eks-cluster.tf`:

```hcl
scaling_config {
  desired_size = 2
  max_size     = 4
  min_size     = 1
}
```

---

## 🛠️ Solução de Problemas

### Problemas Comuns

#### 1. Problemas de Lock do Estado Terraform

```bash
# Forçar desbloqueio se necessário
terraform force-unlock <LOCK_ID>
```

#### 2. Cluster EKS Não Respondendo

```bash
# Verificar status do cluster
aws eks describe-cluster --name <nome-do-cluster> --region <região>

# Verificar status do node group
kubectl get nodes
```

#### 3. Grafana Não Acessível

```bash
# Verificar status do load balancer
kubectl get svc -n monitoring

# Verificar logs dos pods
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

#### 4. Prometheus Não Coletando Métricas

```bash
# Verificar targets do Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Acesse http://localhost:9090/targets
```

### Modo de Debug

Habilite logging detalhado:

```bash
export TF_LOG=DEBUG
terraform apply
```

---

## 🗺️ Roadmap

### Melhorias Planejadas

- [ ] **Documentação Completa**
  - Diagramas de arquitetura com interações detalhadas de componentes
  - Runbooks para tarefas operacionais comuns
  - Procedimentos de recuperação de desastres
  - Guias de otimização de custos

- [ ] **Otimização do GitHub Actions**
  - Leitura direta do state em vez de mecanismos de output/export
  - Melhoria no tratamento de erros e procedimentos de rollback
  - Integração com workflows de pull request

- [ ] **Implementação de SSL/TLS**
  - Integração com AWS Certificate Manager
  - Renovação automática de certificados
  - Execução obrigatória de HTTPS para todos os endpoints
  - Suporte a domínios personalizados

- [ ] **Armazenamento Persistente**
  - Criação de PV/PVC para persistência de dados do Prometheus
  - Provisionamento de volumes EBS com IOPS apropriados
  - Procedimentos de backup e restore
  - Otimização de storage classes

- [ ] **Implementação de GitOps**
  - Substituir deployments Helm baseados em Terraform por ArgoCD/Flux
  - Gerenciamento declarativo de aplicações
  - Sincronização automática com repositório Git
  - Integração de rollback e controle de versão

- [ ] **Capacidades de Monitoramento Adicionais**
  - Monitoramento de Performance de Aplicação (APM)
  - Integração de tracing distribuído
  - Coleta de métricas personalizadas
  - Alertas avançados com integração PagerDuty/Slack

- [ ] **Melhorias de Segurança**
  - IRSA (IAM Roles for Service Accounts)
  - Implementação de Pod Security Standards
  - Aplicação de políticas de rede
  - Criptografia de secrets em repouso

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, siga estas diretrizes:

1. **Fork o repositório**
2. **Crie um branch de funcionalidade**
   ```bash
   git checkout -b feature/nova-funcionalidade
   ```
3. **Commit suas mudanças**
   ```bash
   git commit -m 'Adiciona nova funcionalidade'
   ```
4. **Push para o branch**
   ```bash
   git push origin feature/nova-funcionalidade
   ```
5. **Abra um Pull Request**

### Diretrizes de Desenvolvimento

- Siga as melhores práticas do Terraform
- Use nomes de variáveis e recursos significativos
- Inclua campos `description` para todas as variáveis
- Escreva testes para novas funcionalidades
- Atualize a documentação para qualquer alteração

---

## 📄 Licença

Este projeto é software proprietário. Todos os direitos reservados.

---

## 📞 Suporte

Para perguntas ou problemas:
- Crie uma issue no repositório
- Entre em contato com os mantenedores diretamente
- Revise a seção de solução de problemas acima

---

**Última Atualização**: Março de 2026  
**Mantenedor**: Equipe ps-sl  
**Versão**: 1.0.0