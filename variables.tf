
variable "prefix" {
  type        = string
  default     = "tf"
  description = "A name tag to prefix all resources for easier identification"

}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
}

variable "cidr_block" {
  type        = string
  description = "Cidr block in prefix/mask format for vpc has to be /16"

}

variable "no_of_secgw_in_azs" {
  description = "Number of AZ in which security gateway(vsrx) will be deployed"
  type        = number
  default     = 2
}

variable "vsrx_instance_type" {
  description = "Instance type to deploy vSRX"
  type        = string
  default     = "c4.xlarge"

}

variable "vsrx_ami_ssm_name" {
  description = "SSM value where vsrx AMIID is stored"
  type = string
}

variable "region" {
  type = string
  description = "AWS region where resource is being deployed" 
}

variable "aws_cfg_profile" {
  type = string
  description = "aws cli profile name used for access"
}


variable "key_name" {
  description = "Publik Key Name. Public key should already be uploaded in AWS for the region"
  type        = string

}

variable "jump_host_instance_type" {
  description = "Jump host instance type"
  default = "t2.micro"
  type = string
}

variable "test_instance_type" {
  description = "test instance type"
  type = string 
  default = "t2.micro"
}
variable "test_inst_ami" {
  description = "jump host and test instance ami. Same AMI is used for both test and jump host instances"
  type = string
  default = "ami-04505e74c0741db8d"
}

variable "num_of_test_instances_per_lansubnet" {
  description = "Number of test instances to be deployed per lan subnet"
  type = number
  default = 1
}


locals {
  subnet_bits                  = 8
  created_by_w_prefix          = "${var.prefix}-tf"
  vpc_name_w_prefix            = "${var.prefix}-${var.vpc_name}"
  subnet_names                 = ["management", "internet", "lan"]
  azs                          = slice(data.aws_availability_zones.az.names, 0, var.no_of_secgw_in_azs)
  num_of_total_subnets_per_vpc = length(local.azs) * length(local.subnet_names)
  iterator                     = range(local.num_of_total_subnets_per_vpc)
  num_of_inst_list  = range(0,var.num_of_test_instances_per_lansubnet,1)

  subnet_cidr_list = [for iter in local.iterator : cidrsubnet(var.cidr_block, local.subnet_bits, index(local.iterator, iter))]
  temp_subnets = flatten([
    for index, az in local.azs : [
      for sub_index, subnet in local.subnet_names : {
        vpc_name = aws_vpc.onprem_sim_vpc.tags.Name
        vpc_id   = aws_vpc.onprem_sim_vpc.id
        az_name  = az
        subnet_name             = subnet
        subnet_type             = sub_index == 2 ? "private" : "public"
        map_public_ip_on_launch = sub_index == 2 ? false : true
      }
    ]
  ])
  subnets = flatten([
    for index, subnet in local.temp_subnets : {
      vpc_name                = subnet.vpc_name
      vpc_id                  = subnet.vpc_id
      az_name                 = subnet.az_name
      cidr_subnet             = local.subnet_cidr_list[index]
      subnet_name             = subnet.subnet_name
      subnet_type             = subnet.subnet_type
      map_public_ip_on_launch = subnet.map_public_ip_on_launch
    }
  ])


  sg_names = ["Management_public_SecGroup", "Internet_public_SecGroup", "Lan_private_SecGroup"]

  # SG related locals 
  http_port     = 80
  https_port    = 443
  ssh_port      = 22
  ike_port      = 500
  ike_natt_port = 4500
  port_any      = 0
  protocol_tcp  = "tcp"
  protocol_udp  = "udp"
  protocol_icmp = "icmp"
  protocol_any  = "-1"
  all_ip        = ["0.0.0.0/0"]

  # EIP Tags 
  eip_tags = flatten([
    for az in local.azs : [
      for subnet in slice(local.subnet_names, 0, 2) : {
        name = "${az}-${subnet}"
      }

    ]
  ])
  # Map for building ENIS for vsrx and assiging respective security groups
  enis_vsrx = flatten([
    for az in local.azs : [
      for subnet in slice(local.subnet_names, 1, 3) : {
        name         = "${az}-${subnet}-eni"
        subnet_id    = aws_subnet.onprem_sim_subnet["qmar-onpremsim-vpc.${az}.${subnet}"].id
        sec_group_id = aws_subnet.onprem_sim_subnet["qmar-onpremsim-vpc.${az}.${subnet}"].tags.Name == "internet" ? aws_security_group.my-sg["Internet_public_SecGroup"].id : aws_security_group.my-sg["Lan_private_SecGroup"].id
      }
    ]
  ])

  vsrx_instances = flatten([
    for index, az in local.azs : [
      for subnet in slice(local.subnet_names, 0, 1) : {
        name        = "vsrxgw-${az}-${local.vpc_name_w_prefix}"
        subnet_id   = aws_subnet.onprem_sim_subnet["qmar-onpremsim-vpc.${az}.${subnet}"].id
        wan_intf_id = aws_network_interface.enis_for_vsrx["${az}-internet-eni"].id
        lan_intf_id = aws_network_interface.enis_for_vsrx["${az}-lan-eni"].id
        az_index    = index

      }
    ]
  ])

  eip_vsrx_ass = flatten([
    for index, az in local.azs : {
      inst_id         = aws_instance.vsrxs["vsrxgw-${az}-qmar-onpremsim-vpc"].id
      eip_id          = aws_eip.vsrx_eip["${az}-management"].id
      eip_id_internet = aws_eip.vsrx_eip["${az}-internet"].id
      eni_id_internet = aws_network_interface.enis_for_vsrx["${az}-internet-eni"].id

    }
  ])

  eni_vsrx_ass = flatten([
    for index, az in local.azs : [
      for dev_idx, subnet in slice(local.subnet_names, 1, 3) : {
        inst_id   = aws_instance.vsrxs["vsrxgw-${az}-qmar-onpremsim-vpc"].id
        eni_id    = aws_network_interface.enis_for_vsrx["${az}-${subnet}-eni"].id
        dev_index = dev_idx + 1

      }
    ]
  ])

  
  test_inst_info = flatten([
    for az in local.azs : [
      for  inst_count in local.num_of_inst_list : {
        inst_name        = "inst-${local.vpc_name_w_prefix}-${az}-${inst_count+1}"
        subnet_id   = aws_subnet.onprem_sim_subnet["${local.vpc_name_w_prefix}.${az}.lan"].id

      }
    ]
  ])


} 