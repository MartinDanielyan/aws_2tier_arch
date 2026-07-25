
# Create Secrets Manager secret for database credentials
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project}-db-credentials"
  description             = "Database credentials for ${var.project} ${var.environment} environment"
  recovery_window_in_days = var.recovery_window_in_days

  # Force immediate deletion on destroy (0 days recovery window)
  # Only use in dev/test environments!
  # For production, keep recovery_window_in_days = 7 or higher
  lifecycle {
    # Prevent accidental deletion in production
    prevent_destroy = false
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project}-db-credentials"
      Environment = var.environment
    }
  )
}


# Store database credentials in secret
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password # References the input variable now
    engine   = "postgres"
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
  })
}
