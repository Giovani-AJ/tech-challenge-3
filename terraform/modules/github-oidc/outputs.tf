output "role_arn" {
  description = "Cole em cada repo como AWS_GITHUB_ACTIONS_ROLE_ARN (variável/secret do repo)"
  value       = aws_iam_role.github_actions.arn
}
