
# Generate random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Secrets Manager Module
module "secrets" {
  source = "./modules/secrets"

  project     = var.project
  environment = var.environment
  db_name     = var.db_name
  db_username = var.db_username
  db_password = random_password.db_password.result
  db_host     = module.rds.db_address

  tags = var.tags

}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project               = var.project
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  enable_nat_gateway    = var.enable_nat_gateway
  single_nat_gateway    = var.single_nat_gateway

  tags = var.tags
}


# Security Groups Module
module "security_groups" {
  source = "./modules/security_groups"

  project     = var.project
  environment = var.environment
  vpc_id      = module.vpc.vpc_id

  tags = var.tags
}


# RDS Module
module "rds" {
  source = "./modules/rds"

  environment       = var.environment
  project           = var.project
  subnet_ids        = module.vpc.database_subnet_ids
  security_group_id = module.security_groups.rds_sg_id
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = random_password.db_password.result

  tags = var.tags
}


# EC2 Module
module "ec2" {
  source = "./modules/ec2"

  project_name          = var.project
  environment           = var.environment
  instance_type         = var.ec2_instance_type
  public_subnet_id      = module.vpc.public_subnet_ids[0]
  web_security_group_id = module.security_groups.web_sg_id
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = random_password.db_password.result
  db_host               = module.rds.db_address


  depends_on = [module.vpc, module.security_groups, module.rds]

}

