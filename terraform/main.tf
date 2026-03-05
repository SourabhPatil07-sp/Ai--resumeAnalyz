data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-server-sg"
  description = "Security group for Jenkins server"

  # SSH (Restricted to your IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins Agents (optional)
  ingress {
    from_port   = 50000
    to_port     = 50000
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
    Name = "jenkins-server-sg"
  }
}

resource "aws_instance" "jenkins_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = "my-key"

  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "jenkins-server"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    apt-get update -y

    # Install Java
    apt-get install -y openjdk-17-jdk

    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker ubuntu

    # Add official Jenkins repository key and list file (uses the stable LTS packages)
    # the default Ubuntu repo often contains a very old Jenkins release, which
    # is why you were seeing "old version" and failures during provisioning.
    # The following steps follow the instructions from pkg.jenkins.io and
    # ensure the package comes from the Jenkins project itself.

    # install prerequisites for managing keys
    apt-get install -y gnupg curl

    # fetch the signing key and store it in a keyring
    wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
      | gpg --dearmor | tee /usr/share/keyrings/jenkins-archive-keyring.gpg > /dev/null

    # add the repository; remove "-stable" and use "debian" if you want the
    # weekly (cutting‑edge) builds instead of the LTS line
    echo "deb [signed-by=/usr/share/keyrings/jenkins-archive-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" \
      | tee /etc/apt/sources.list.d/jenkins.list

    # refresh and install; you can pin a version by appending =<version> here
    apt-get update -y
    apt-get install -y jenkins

    usermod -aG docker jenkins

    systemctl enable jenkins
    systemctl start jenkins

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Install Terraform
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/hashicorp.list

    apt-get update -y
    apt-get install -y terraform
  EOF
}
