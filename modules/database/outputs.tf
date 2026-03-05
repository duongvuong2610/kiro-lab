output "endpoint" {
  description = "Database endpoint (address:port)"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "Database hostname"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Name of the database"
  value       = aws_db_instance.main.db_name
}

output "security_group_id" {
  description = "Security group ID for database access"
  value       = aws_security_group.rds.id
}
