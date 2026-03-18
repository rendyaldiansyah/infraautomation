output "vpc_id" {
  value = aws_vpc.this.id
}
output "subnet_ids" {
  value = aws_subnet.private[*].id
}
output "private_route_table_id" {
  value = aws_route_table.private.id
}
output "region" {
  value = var.aws_region
}
output "sg_monitoring_id" {
  description = "Security Group ID for monitoring ECS tasks"
  value       = aws_security_group.vpce.id
}
