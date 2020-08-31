provider "aws" {
  region = "ap-south-1"
  profile = "yash"
}


resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
 

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "TLS from VPC"
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
    Name = "allow_tls"
  }
}


resource "tls_private_key" "mykey" {
  algorithm = "RSA"
}

output "key_ssh" {
  value = tls_private_key.mykey.public_key_openssh
}

output "pubkey"{
  value = tls_private_key.mykey.public_key_pem
}

resource "aws_key_pair" "opensshkey"{
  key_name = "yashkey"
  public_key = tls_private_key.mykey.public_key_openssh
}

resource "aws_instance" "web" {
  depends_on = [ 
    aws_security_group.allow_tls,
    ]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.opensshkey.key_name
  security_groups = [ "allow_tls" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mykey.private_key_pem
    host     = aws_instance.web.public_ip
  }

 
  }



resource "aws_efs_file_system" "EFS-task"{
 creation_token="efs"

 tags = {
Name= "EFS-task"
 }
}


resource "aws_efs_mount_target" "mount" {
file_system_id = aws_efs_file_system.EFS-task.id
subnet_id = "subnet-29edd741"
security_groups= [aws_security_group.allow_tls.id]
}

resource "null_resource" "mounting" {
depends_on = [ aws_efs_mount_target.mount, ]

  connection  { 
             type = "ssh"
             user = "ec2-user"
             private_key = tls_private_key.mykey.private_key_pem
             host = aws_instance.web.public_ip
      }
provisioner "remote-exec" {
    inline = [ 
                   "sudo yum install httpd php git -y",
                   "sudo systemctl restart httpd",
                   "sudo systemctl enable httpd",
                   "sudo mkfs.ext4  /dev/xvdh",
                   " sudo mount /dev/xvdh  /var/www/html",
                   " sudo rm -rf /var/www/html/*",
                   "sudo git clone https://github.com/yash2703/terraformaws.git /var/www/html/",
                   "sudo yum install nfs-utils -y"
                  ]
          }
   }





resource "aws_s3_bucket" "bucket" {
  bucket = "yash2703-bucket"
  acl    = "public-read"


}

resource "aws_s3_bucket_object" "examplebucket_object" {
  key                    = "someobject1.jpg"
  bucket                 = "${aws_s3_bucket.bucket.id}"
   acl    = "public-read"
  source         = "C:/Users/Yash Kedia/imagestask2.jpg"



  force_destroy = true
  
}
locals {
	s3_origin_id = "S3-${aws_s3_bucket.bucket.bucket}"
}

resource "aws_cloudfront_distribution" "cloudfront" {

	enabled = true
	is_ipv6_enabled = true
	
	origin {
		domain_name = aws_s3_bucket.bucket.bucket_domain_name
		origin_id = local.s3_origin_id
	}
	
	default_cache_behavior {
    		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    		cached_methods   = ["GET", "HEAD"]
    		target_origin_id = local.s3_origin_id

    		forwarded_values {
      			query_string = false

      			cookies {
        			forward = "none"
      			}
    		}
    		
    		viewer_protocol_policy = "allow-all"
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
    		private_key = tls_private_key.mykey.private_key_pem
    		
                host     = aws_instance.web.public_ip
  	}
  	provisioner "remote-exec" {
  		
  		inline = [
  			
  			"sudo su << EOF",
            		"echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.examplebucket_object.key}' width='300' height='380'>\" >> /var/www/html/index.php",
            		"EOF",	
  		]
  	}
}

output "Instance-Public-IP" {
	value = aws_instance.web.public_ip
}


resource "null_resource" "nulllocal1"  {




	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.web.public_ip}"
  	}
}




