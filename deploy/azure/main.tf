locals {
  # Create a regional cluster in current region by default.
  credential_path = "${path.cwd}/credentials"
  kubeconfig_path = "${local.credential_path}/kubeconfig_${var.aks_name}"
}

provider "azurerm" {
  features {}
}

module "vpc" {
  source = "../modules/azure/vpc"

  create_vpc                    = var.create_vpc
  resource_group                = var.resource_group
  region                        = var.region
  vpc_name                      = var.vpc_name
}

module "key-pair" {
  source                        = "../modules/azure/key-pair"

  name                          = var.aks_name
  region                        = var.region
  resource_group                = var.resource_group
  path                          = local.credential_path
}

module "aks" {
  depends_on                    = [module.vpc, module.key-pair]
  source                        = "../modules/azure/aks"

  aks_name                      = var.aks_name
  aks_version                   = var.aks_version
  region                        = var.region
  resource_group                = var.resource_group
  vpc_name                      = module.vpc.vpc_name
  availability_zones            = var.availability_zones
  ssh_key_data                  = module.key-pair.public_key_openssh
  kubeconfig_path               = local.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path                 = module.aks.kubeconfig_path
  }
}

module "tidb-operator" {
  depends_on                    = [module.aks]
  source                        = "../modules/azure/tidb-operator"

  kubeconfig_path               = module.aks.kubeconfig_path
  tidb_operator_version         = var.tidb_operator_version
  operator_helm_values          = var.operator_helm_values == "" ? var.operator_helm_values_file == "" ? "" : file(var.operator_helm_values_file) : var.operator_helm_values
}

