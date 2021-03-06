provider "aws" {
 region= "ap-south-1"
 profile = "aws_user"
}


 

resource "aws_key_pair" "mykey"{
 key_name = "myawskey"
 public_key ="ssh-rsa AAAABS1nBgXL4Xw2YinBGUxfdbhuegwbuyewhgbyUH2oyGcAJHBCNtxHg7gDiESe33zafoVtf"
}



resource "aws_security_group" "sg" {
  name        = "sg_for_aws_instance"
  description = "sg to allow port 80 and ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  
  
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 }

resource "aws_instance"  "myinstance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name	= "myawskey"
  security_groups =  ["sg_for_aws_instance"]


 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ishit/Desktop/terraform/task1/myawskey.pem")
    host     = aws_instance.myinstance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]

}

  tags = {
    Name = "mynewos"
  }
}

resource "aws_ebs_volume" "myebs" {
  availability_zone = aws_instance.myinstance.availability_zone
  size              = 1

  tags = {
    Name = "myebsvolume"
  }
}



resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.myebs.id}"
  instance_id = "${aws_instance.myinstance.id}"
  force_detach = true	
}

resource "null_resource" "nullremote"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ishit/Desktop/terraform/task1/myawskey.pem")
    host     = aws_instance.myinstance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/ishita2301/task1.git  /var/www/html/"
    ]
  }
}



resource "aws_s3_bucket" "bucket" {
  bucket = "terraform-bucket-001"
  acl= "private"
  provisioner "local-exec" {
                command = "mkdir new1"
  }
  provisioner "local-exec" {
                command = "git clone https://github.com/ishita2301/task1images.git new1"
  }

  provisioner "local-exec" {

                when = destroy
                command = "rmdir/Q /S new1"
  }
               
  
tags = {
 name = "s3bucket"
}
}


resource "aws_s3_bucket_object" "object" {

depends_on = [
    aws_s3_bucket.bucket,
  ]
  acl = "public-read"
  bucket = aws_s3_bucket.bucket.id
  key    = "terra.jpg"
  source =  "C:/Users/ishit/Downloads/terra.jpg"
  content_type = "image/jpg"

} 



locals {
  s3_origin_id = "s3-${aws_s3_bucket.bucket.bucket}"
}




resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "${local.s3_origin_id}"
    

    custom_origin_config {
    http_port= 80
    https_port = 80


    origin_protocol_policy="match-viewer"
    origin_ssl_protocols = ["TLSv1","TLSv1.1","TLSv1.2"]
    }
    }
    enabled = true
    default_root_object = "terra.jpg"
     default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"
    

    forwarded_values {
      query_string = false
    cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
    
   restrictions {
    geo_restriction {
      restriction_type = "none"
   }
}

   viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ishit/Desktop/terraform/task1/myawskey.pem")
    host     = aws_instance.myinstance.public_ip
  }

provisioner "remote-exec" {
    inline = [

      "sudo su << EOF",
      "echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.object.key}'>\" >> /var/www/html/index.html",
      "EOF",
    ]

} 

  tags = {
    Environment = "distribution"
  }

}

resource "null_resource" "nulllocal1"  {


depends_on = [
    aws_cloudfront_distribution.s3_distribution,
  ]

	

        provisioner "local-exec" {
	    command = "chrome  http://${aws_instance.myinstance.public_ip}"
  	}
}








