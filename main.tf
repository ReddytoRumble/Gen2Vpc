provider "aws" {
  region     = "us-east-1"
}


resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags {
    label = "scenario-2-vpc"
  }
}


resource "aws_subnet" "public_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"

  tags {
    Name = "private-subnet"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route_table" "public_routetable" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }

  tags {
    label = "public-routetable"
  }
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.public_routetable.id}"
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"
}

resource "aws_route_table" "private_routetable" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }

  tags {
    label = "private-routetable"
  }
}

resource "aws_route_table_association" "private_subnet" {
  subnet_id      = "${aws_subnet.private_subnet.id}"
  route_table_id = "${aws_route_table.private_routetable.id}"
}

resource "aws_security_group" "db" {
    name = "vpc_db"
    description = "Allow incoming database connections."

    ingress { # SQL Server
        from_port = 1433
        to_port = 1433
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress { # MySQL
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    vpc_id = "${aws_vpc.vpc.id}"

    tags {
        Name = "DBServerSG"
    }
}

resource "aws_security_group" "web" {
    name = "vpc_web"
    description = "Allow incoming HTTP connections."

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress { # SQL Server
        from_port = 1433
        to_port = 1433
        protocol = "tcp"
        security_groups = ["${aws_security_group.db.id}"]
    }
    egress { # MySQL
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = ["${aws_security_group.db.id}"]
    }

    vpc_id = "${aws_vpc.vpc.id}"

    tags {
        Name = "WebServerSG"
    }
}

resource "aws_instance" "test_instance"{
  count = "${var.number_of_instances}"
  ami = "ami-8c1be5f6"
  availability_zone = "us-east-1a"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public_subnet.id}"
  key_name = "nithin-sample"
  security_groups = ["${aws_security_group.db.id}"]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              yum install -y docker
              service docker start
              docker run hello-world
              EOF
}
