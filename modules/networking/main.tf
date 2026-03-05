# VPC Resource
resource "aws_vpc" "main" {
  cidr_block           = var.config.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.config.environment}-vpc"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.config.public_subnet_cidrs[count.index]
  availability_zone       = var.config.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.config.environment}-public-subnet-${count.index + 1}"
    Environment = var.config.environment
    ManagedBy   = "terraform"
    Type        = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.config.private_subnet_cidrs[count.index]
  availability_zone = var.config.availability_zones[count.index]

  tags = {
    Name        = "${var.config.environment}-private-subnet-${count.index + 1}"
    Environment = var.config.environment
    ManagedBy   = "terraform"
    Type        = "private"
  }
}
# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.config.environment}-igw"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.config.environment}-nat-eip"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway in first public subnet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.config.environment}-nat-gateway"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.config.environment}-public-rt"
    Environment = var.config.environment
    ManagedBy   = "terraform"
    Type        = "public"
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.config.environment}-private-rt"
    Environment = var.config.environment
    ManagedBy   = "terraform"
    Type        = "private"
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
