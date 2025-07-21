###############################################
#  RDS PostgreSQL                             #
###############################################
resource "aws_db_subnet_group" "db" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = local.project_tag
}

resource "aws_db_instance" "postgres" {
  identifier              = "project-db"
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "16.9"
  instance_class          = "db.t3.micro"
  username                = "myuser"
  password                = "mypassword"
  db_name                 = "mydatabase"
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db.name
  availability_zone       = "eu-north-1a"
  publicly_accessible     = false
  skip_final_snapshot     = true
  tags                    = local.project_tag
}
