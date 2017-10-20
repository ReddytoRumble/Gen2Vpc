provider "aws" {
  region     = "us-east-1"
}

module "gen_two_vpc" {
  source = "./modules/genTwoVpc"
  availability_zone = "${var.availability_zone}"
}



resource "aws_security_group" "db" {
    name = "Db-Security-Group"
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

    vpc_id = "${module.gen_two_vpc.vpc}"

    tags {
        Name = "DBServerSG"
    }
}

resource "aws_security_group" "web" {
    name = "Web-Security-Group"
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

    vpc_id = "${module.gen_two_vpc.vpc}"

    tags {
        Name = "WebServerSG"
    }
}

resource "aws_instance" "test_instance"{
  count = "${var.number_of_instances}"
  ami = "ami-8c1be5f6"
  availability_zone = "${var.availability_zone}"
  instance_type = "t2.micro"
  subnet_id = "${module.gen_two_vpc.public_subnet}"
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
