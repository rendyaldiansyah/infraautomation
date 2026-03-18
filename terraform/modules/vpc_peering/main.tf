terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.oregon]
    }
  }
}

# Step 1: Create peering connection from us-east-1 (requester)
resource "aws_vpc_peering_connection" "this" {
  vpc_id        = var.requester_vpc_id
  peer_vpc_id   = var.accepter_vpc_id
  peer_region   = var.peer_region      # REQUIRED for inter-region
  peer_owner_id = var.peer_owner_id
  # auto_accept CANNOT be used for inter-region peering
  tags = { Name = var.peering_name }
}

# Step 2: Accept from us-west-2 (accepter) using Oregon provider alias
resource "aws_vpc_peering_connection_accepter" "this" {
  provider                  = aws.oregon
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  auto_accept               = true
  tags                      = { Name = "${var.peering_name}-accepter" }
}

# Step 3: Route in Virginia private RT → Oregon monitoring VPC
resource "aws_route" "to_monitoring" {
  route_table_id            = var.requester_route_table_id
  destination_cidr_block    = var.accepter_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  depends_on                = [aws_vpc_peering_connection_accepter.this]
}

# Step 4: Route in Oregon monitoring RT → Virginia app VPC
resource "aws_route" "to_app" {
  provider                  = aws.oregon
  route_table_id            = var.accepter_route_table_id
  destination_cidr_block    = var.requester_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  depends_on                = [aws_vpc_peering_connection_accepter.this]
}

# NOTE: DNS resolution options are NOT supported for inter-region peering.
# Do NOT create aws_vpc_peering_connection_options — it will throw an error.
