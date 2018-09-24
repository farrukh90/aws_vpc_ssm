provider "aws" {
    region = "${var.aws_region}"
}

resource "aws_vpc" "foo" {
    cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
    cidr_block = "10.0.1.0/24"
    vpc_id = "${aws_vpc.foo.id}"
}

resource "aws_internet_gateway" "main" {
    vpc_id = "${aws_vpc.foo.id}"
}

resource "aws_route_table" "default" {
    vpc_id = "${aws_vpc.foo.id}"

    route {
        cidr_block = "YOUR-IP/32"
        gateway_id = "${aws_internet_gateway.main.id}"
    }
}

resource "aws_route_table_association" "public" {
  subnet_id = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.default.id}"
}

resource "aws_vpc_endpoint" "private-s3" {
    vpc_id = "${aws_vpc.foo.id}"
    service_name = "com.amazonaws.us-west-2.s3"
    route_table_ids = ["${aws_route_table.default.id}"]
    policy = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}

resource "aws_instance" "test" {
    ami = "ami-e7527ed7"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.public.id}"
    key_name = "coreos-test"
    associate_public_ip_address = true
    security_groups = ["${aws_security_group.allow_ssh.id}"]
    iam_instance_profile = "${aws_iam_instance_profile.test_profile.id}"
}

# IAM
resource "aws_iam_instance_profile" "test_profile" {
    name = "test_profile"
    roles = ["${aws_iam_role.role.name}"]
}

resource "aws_iam_role" "role" {
    name = "test_role"
    path = "/"
    assume_role_policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {"AWS": "*"},
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "test_policy" {
    name = "test_policy"
    role = "${aws_iam_role.role.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowS3Listing",
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:ListBucket"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

# SG
resource "aws_security_group" "allow_ssh" {
    vpc_id = "${aws_vpc.foo.id}"
    name = "allow_ssh"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

output "public_ip" {
    value = "${aws_instance.test.public_ip}"
}
