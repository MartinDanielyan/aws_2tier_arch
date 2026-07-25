
data "aws_availability_zones" "available" {
  state = "available"
}

##########
# VPC
##########

resource "aws_vpc" "this" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = var.vpc_instance_tenancy

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-vpc"
      Environment = var.environment
    }
  )
}

##################
# Internet Gateway
##################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-igw"
      Environment = var.environment
    }
  )
}

###############
# Public Subnet
###############

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-public-subnet-${count.index + 1}"
      Environment = var.environment
      Tier        = "public"
    }
  )
}

#########################
# Private Subnet
#########################

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.private_subnet_cidrs[count.index]

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-private-subnet-${count.index + 1}"
      Environment = var.environment
      Tier        = "private"
    }
  )
}

#######################################
# Database Isolated Subnets (Data Tier)
#######################################

resource "aws_subnet" "database" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.database_subnet_cidrs[count.index]

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-database-subnet-${count.index + 1}"
      Environment = var.environment
      Tier        = "database"
    }
  )
}

############################
# NAT Gateways configuration
############################

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-nat-eip-${count.index + 1}"
      Environment = var.environment
    }
  )

  depends_on = [aws_internet_gateway.this]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-nat-gw-${count.index + 1}"
      Environment = var.environment
    }
  )

  depends_on = [aws_internet_gateway.this]
}

################################
# Route Table for Public Subnets
################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-public-rt"
      Environment = var.environment
      Tier        = "public"
    }
  )
}

# Route for Public Subnets to Internet Gateway
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


###################################
# Route Table for Private Subnets
###################################

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? length(var.availability_zones) : 0
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-private-rt-${count.index + 1}"
      Environment = var.environment
      Tier        = "private"
    }
  )
}

# Route for Private Subnets to NAT Gateway
resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? length(var.availability_zones) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# Associate Private Subnets with Private Route Tables
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private[count.index].id : null
}

##################################
# Route Table for Database Subnets (No internet access)
##################################

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-database-rt"
      Environment = var.environment
      Tier        = "database"
    }
  )
}

# Associate Database Subnets with Database Route Table
resource "aws_route_table_association" "database" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

