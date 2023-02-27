# Deploy-a-High-Availability-Web-App-Using-Terraform

I did that project before using CloudFormation and since i was learning terraform i decided to do it with it
it was fun experiment 

Draw for the project
--------------------
![img-1](Diagram-Of-Udagram-Project.jpeg)

Run Terraform
-------------

- terraform init: Setup a new terraform project for this file.
- terraform apply: Setup the infrastructure as it’s defined in the .tf file.
- terraform destroy: Tear down everything that terraform created.
- terraform state list: Show everything that was created by terraform.
- terraform state show aws_instance.web_instance: Show the details about the ec2 in-
stance that was deployed