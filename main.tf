terraform {
    required_version = ">= 1.0"
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 4.0"
        }
    }
}

provider "aws" {
    region = var.region
}

variable "region" {
    description = "AWS region"
    type        = string
    default     = "ap-south-1"
}

data "aws_availability_zones" "available" {
    state = "available"
}

resource "aws_vpc" "main" {
    cidr_block           = "10.75.0.0/20"
    enable_dns_support   = true
    enable_dns_hostnames = true

    tags = {
        Name = "main-vpc"
    }
}

# Public subnets (2) - /24
resource "aws_subnet" "public" {
    count                   = 2
    vpc_id                  = aws_vpc.main.id
    cidr_block              = element(["10.0.1.0/24", "10.0.2.0/24"], count.index)
    availability_zone       = data.aws_availability_zones.available.names[count.index]
    map_public_ip_on_launch = true

    tags = {
        Name = "public-${count.index + 1}"
    }
}

# Private subnets (2) - /24
resource "aws_subnet" "private" {
    count             = 2
    vpc_id            = aws_vpc.main.id
    cidr_block        = element(["10.0.11.0/24", "10.0.12.0/24"], count.index)
    availability_zone = data.aws_availability_zones.available.names[count.index]

    tags = {
        Name = "private-${count.index + 1}"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "main-igw"
    }
}

# Public route table with route to IGW
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "public-rt"
    }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public_assoc" {
    count          = length(aws_subnet.public)
    subnet_id      = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

output "vpc_id" {
    value = aws_vpc.main.id


output "public_subnet_ids" {
    value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
    value = aws_subnet.private[*].id
}