# This was gotten from Provider in https://registry.terraform.io/providers/hashicorp/aws/latest/docs

provider "aws" {
  region     = "eu-west-2"
  access_key = "################"
  secret_key = "#############################"
}

# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {

  tags = {
    Name = "default vpc"
  }
}


# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}


# create default subnet if one does not exit
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet"
  }
}


# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 80 and 22"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2 security group"
  }
}




# use data source to get a registered amazon linux 2 ami
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}



# launch the ec2 instance and install website
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "sternpay_keypair"

  tags = {
    Name = "test-server"
  }
}


# print the ec2's public ipv4 address
output "public_ipv4_address" {
  value = aws_instance.ec2_instance.public_ip
}


################################################################################################
# create default subnet if one does not exit
resource "aws_default_subnet" "subnet_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "db subnet 1"
  }
}

# create default subnet if one does not exit
resource "aws_default_subnet" "subnet_az2" {
  availability_zone = data.aws_availability_zones.available_zones.names[1]

  tags = {
    Name = "default subnet 2"
  }
}


# create security group for the database
resource "aws_security_group" "database_security_group" {
  name        = "database security group"
  description = "enable mysql/aurora access on port 3306"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    description = "PostgreSQL access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database security group"
  }
}


# create the subnet group for the rds instance
resource "aws_db_subnet_group" "database_subnet_group_1" {
  name        = "database-subnets"
  subnet_ids  = [aws_default_subnet.subnet_az1.id, aws_default_subnet.subnet_az2.id]
  description = "subnets for database instance"

  tags = {
    Name = "database-subnets-1"
  }
}


# Create the RDS instance
resource "aws_db_instance" "db_instance" {
  engine         = "postgres"
  engine_version = "11.16" # Specify the desired PostgreSQL version

  multi_az = false # Set to true for Multi-AZ deployment, if needed

  identifier = "sternpay-postgres-db" # Unique identifier for the RDS instance
  username   = "devops"
  password   = "#################"

  instance_class    = "db.t2.micro" # Specify the instance type
  allocated_storage = 20            # Specify the allocated storage in GB

  db_subnet_group_name = aws_db_subnet_group.database_subnet_group_1.name # Name of the DB subnet group

  vpc_security_group_ids = [aws_security_group.database_security_group.id] # List of security group IDs

  availability_zone   = data.aws_availability_zones.available_zones.names[0]
  db_name             = "sternpaydb"
  skip_final_snapshot = true

  # Additional optional parameters can be added based on your requirements
  publicly_accessible     = false # Set to true if you want the RDS instance to be publicly accessible
  storage_type            = "gp2" # Specify the storage type
  backup_retention_period = 7     # Specify the backup retention period in days
}
