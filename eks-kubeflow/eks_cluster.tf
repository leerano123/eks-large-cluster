module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.eks_name
  cluster_version = "1.29"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  cluster_addons = {
    eks-pod-identity-agent = {
      most_recent                 = true
      resolve_conflicts_on_update = true
    }
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      preserve = true
    }
    aws-ebs-csi-driver = {}
  }

  vpc_id     = data.terraform_remote_state.infrastructure.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.infrastructure.outputs.private_subnet_ids

  eks_managed_node_group_defaults = {
    disk_size = local.eks_disk_size_gb
  }

  eks_managed_node_groups = {
    "t3-medium-pool01" = {
      min_size     = 1
      max_size     = local.eks_max_node_count
      desired_size = 1

      labels = {
        role = "t3.medium-pool01"
      }

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    },
    "t2-micro-pool01" = {
      min_size     = 0
      max_size     = local.eks_max_node_count
      desired_size = 0

      labels = {
        role = "t2.micro-pool01"
      }

      taints = [{
        key    = "inferentia"
        value  = "present"
        effect = "NO_SCHEDULE"
      }]

      instance_types = ["t2.micro"]
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "eks-${var.environment}-kubeflow"
  }

  cluster_security_group_additional_rules = {
    # ingress_wireguard_tcp = {
    #   description = "Access EKS from WireGuard VPN."
    #   protocol    = "tcp"
    #   from_port   = 443
    #   to_port     = 443
    #   type        = "ingress"
    #   # security_groups = [aws_security_group.wireguard_sg.id]
    #   security_groups = data.terraform_remote_state.infra_repo.outputs.wg_security_group_id
    #   cidr_blocks     = data.terraform_remote_state.infra_repo.outputs.vpc_public_subnets_cidr_blocks
    # }
    ingress = {
      description           = "To node 1025-65535"
      type                       = "ingress"
      from_port             = 0
      to_port                  = 0
      protocol                = -1
      cidr_blocks           = ["0.0.0.0/0"]
      source_node_security_group = false
    },
    ingress_codebuild_https = {
      description = "EKS Cluster allows 443 port to get API call"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  manage_aws_auth_configmap = true

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::590183913410:user/eks_user"
      username = "eks_user"
      groups   = ["system:masters"]
    }
  ]
}

resource "null_resource" "kubectl-init" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${local.eks_name} --region ${local.region}"
  }
  depends_on = [module.eks.cluster_id]
}