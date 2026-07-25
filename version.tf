terraform {
  required_version = ">= 1.13.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.36.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7" # Latest stable version (3.7.2)
    }
  }
}
