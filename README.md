# Terraform Workshop
### Team
- Eunice Munsi
- Benedek Brenner

Using hashicorp/aws 5.100 and Terraform v1.17.2.

Link to the repository: [https://github.com/munsinator/iac-terraform-workshop](https://github.com/munsinator/iac-terraform-workshop)

## What we have learned:
- How to manage credentials using AWS CLI (`aws configure`)
- Manage the default VPC
- How to create a VPC and create/manage it's components:

    - Internet Gateway
    - Subnets
    - Route tables
    - Security groups
    - Elastic IP
- How to configure network interfaces
- How to do outputs
- How to create and configure load balancers
- How to use `terraform init`, `terraform plan`, `terraform apply`, `terraform fmt`, `terraform validate`

### HCP Terraform
We use this service to store statefiles securely. When a stage/job in a pipeline finishes, it usually deletes the local files unless you store them somewhere. Terraform Cloud (or others) act as a file store with extra features.


### Issue
I deleted my free HCP Terraform organization, because I signed up at Terraform Cloud first. After deleting the organization there and trying to recreate the organization at HPC Terraform, I now receive a “Free tier organizations created by user limit reached” error. Deleting the organization and deleting caches did not seem to resolve the issue.

#### What we would have done, if that had not happen
-  create a workspace
- add AWS credentials on HCP Terraform and Github
- extract Terraform API Token and add to Github Action secrets
- create `terraform-create` and `terraform-destroy` 


## Screenshots
![](./screenshots/Screenshot%202026-11-24%20211820.png)
![](./screenshots/Screenshot%202026-11-24%20215852.png)
![](./screenshots/Screenshot%202026-11-24%20220034.png)
![](./screenshots/Screenshot%202026-11-26%20182649.png)
![](./screenshots/Screenshot%202026-11-26%20212021.png)
![](./screenshots/Screenshot%202026-11-26%20213250.png)
![](./screenshots/Screenshot%202026-11-26%20231135.png)
![](./screenshots/Screenshot%202026-11-26%20231246.png)
![](./screenshots/Screenshot%202026-11-26%20231310.png)