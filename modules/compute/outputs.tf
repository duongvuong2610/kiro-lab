output "cluster_id" {
  description = "ID of ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "service_name" {
  description = "Name of ECS service"
  value       = aws_ecs_service.main.name
}

output "alb_dns_name" {
  description = "DNS name of ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of ALB"
  value       = aws_lb.main.arn
}

output "task_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "autoscaling_target_id" {
  description = "ID of the auto-scaling target"
  value       = aws_appautoscaling_target.ecs_service.id
}

output "autoscaling_policy_arn" {
  description = "ARN of the auto-scaling policy"
  value       = aws_appautoscaling_policy.ecs_cpu_scaling.arn
}
