
resource "aws_vpc" "onprem_sim_vpc" {

  cidr_block = var.cidr_block
  tags = {
    Name       = local.vpc_name_w_prefix
    Created_by = local.created_by_w_prefix
  }
}

resource "aws_subnet" "onprem_sim_subnet" {

  for_each = {
    for subnet in local.subnets : "${subnet.vpc_name}.${subnet.az_name}.${subnet.subnet_name}" => subnet
  }
  vpc_id                  = each.value.vpc_id
  availability_zone       = each.value.az_name
  cidr_block              = each.value.cidr_subnet
  map_public_ip_on_launch = each.value.map_public_ip_on_launch
  tags = {
    Name = each.value.subnet_name
    Type = each.value.subnet_type
  }
}

# Internet GW 
resource "aws_internet_gateway" "internetgw" {
  vpc_id = aws_vpc.onprem_sim_vpc.id
  tags = {
    Name       = "${var.prefix}-igw-${aws_vpc.onprem_sim_vpc.tags.Name}"
    Created_by = local.created_by_w_prefix
  }
}

# Security Groups 3 total per VPC
## Management Security Group >> Attached to eth0/instance
## Internet Security Group >> Attached to eni eth1/ge-0/0/0 on vSRX Instance 
## Lan security Group >> Attached to eni eth2/ge-0/0/1 on vSRX Instance 

resource "aws_security_group" "my-sg" {
  for_each = toset(local.sg_names)
  vpc_id   = aws_vpc.onprem_sim_vpc.id
  name     = each.value

}

resource "aws_security_group_rule" "allow_all_outbound" {
  for_each          = aws_security_group.my-sg
  security_group_id = each.value.id
  type              = "egress"
  from_port         = local.port_any
  to_port           = local.port_any
  protocol          = local.protocol_any
  cidr_blocks       = local.all_ip
}

resource "aws_security_group_rule" "ssh-in-management" {

  security_group_id = aws_security_group.my-sg["Management_public_SecGroup"].id
  type              = "ingress"

  from_port   = local.ssh_port
  to_port     = local.ssh_port
  protocol    = local.protocol_tcp
  cidr_blocks = local.all_ip

}

resource "aws_security_group_rule" "icmp-in-management" {

  security_group_id = aws_security_group.my-sg["Management_public_SecGroup"].id
  type              = "ingress"

  from_port   = local.port_any
  to_port     = local.port_any
  protocol    = local.protocol_icmp
  cidr_blocks = local.all_ip

}

resource "aws_security_group_rule" "https-in-management" {

  security_group_id = aws_security_group.my-sg["Management_public_SecGroup"].id
  type              = "ingress"

  from_port   = local.https_port
  to_port     = local.https_port
  protocol    = local.protocol_tcp
  cidr_blocks = local.all_ip

}

resource "aws_security_group_rule" "icmp-ipsec-500-in-internet" {

  security_group_id = aws_security_group.my-sg["Internet_public_SecGroup"].id
  type              = "ingress"
  from_port         = local.ike_port
  to_port           = local.ike_port
  protocol          = local.protocol_udp
  cidr_blocks       = local.all_ip
}

resource "aws_security_group_rule" "icmp-ipsec-4500-in-internet" {

  security_group_id = aws_security_group.my-sg["Internet_public_SecGroup"].id
  type              = "ingress"
  from_port         = local.ike_natt_port
  to_port           = local.ike_natt_port
  protocol          = local.protocol_udp
  cidr_blocks       = local.all_ip
}

resource "aws_security_group_rule" "icmp-in-internet" {

  security_group_id = aws_security_group.my-sg["Internet_public_SecGroup"].id
  type              = "ingress"

  from_port   = local.port_any
  to_port     = local.port_any
  protocol    = local.protocol_icmp
  cidr_blocks = local.all_ip

}

resource "aws_security_group_rule" "icmp-in-lan" {

  security_group_id = aws_security_group.my-sg["Lan_private_SecGroup"].id
  type              = "ingress"
  from_port         = local.port_any
  to_port           = local.port_any
  protocol          = local.protocol_icmp
  cidr_blocks       = local.all_ip

}

resource "aws_security_group_rule" "ssh-in-lan" {

  security_group_id = aws_security_group.my-sg["Lan_private_SecGroup"].id
  type              = "ingress"
  from_port         = local.ssh_port
  to_port           = local.ssh_port
  protocol          = local.protocol_tcp
  cidr_blocks       = local.all_ip
}

resource "aws_security_group_rule" "https-in-lan" {

  security_group_id = aws_security_group.my-sg["Lan_private_SecGroup"].id
  type              = "ingress"
  from_port         = local.https_port
  to_port           = local.https_port
  protocol          = local.protocol_tcp
  cidr_blocks       = local.all_ip

}


# create vSRX instance one per management subnet in each AZ 

resource "aws_instance" "vsrxs" {
  # Move the data block and this to root module from here. Leave this as var ... 
  for_each = {
    for vsrx in local.vsrx_instances : vsrx.name => vsrx
  }
  ami                         = data.aws_ssm_parameter.vsrx_img_id.value
  instance_type               = var.vsrx_instance_type
  subnet_id                   = each.value.subnet_id
  key_name                    = var.key_name
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.my-sg["Management_public_SecGroup"].id]
  # Note the default ENI with the instance will be mapped to fxp0
  # Attaching WAN/Internet ENI - mapped to ge-0/0/0  
  /*   network_interface {

    network_interface_id = each.value.wan_intf_id
    device_index         = 1
  }
  # Attaching LAN ENI - mapped to ge-0/0/1 
  network_interface {

    network_interface_id = each.value.lan_intf_id
    device_index         = 2
  } */

  tags = {
    Name       = each.value.name
    Created_by = local.created_by_w_prefix
  }
  lifecycle {
    ignore_changes = [associate_public_ip_address]
  }
}

# Create Test Instance in the private/lab subnet 

# Create a bashion host in the management subnet

# ENI (Elastic Network interface) 
## 1 ENI - qmar-test-vpc.us-east-1a.internet
## 1 ENI - qmar-test-vpc.us-east-1a.lan 
## 1 ENI - qmar-test-vpc.us-east-1b.internet
## 1 ENI - qmar-test-vpc.us-east-1b.lan
##  Management subnet will use the default ENI 
## Attach instance and SG to the respective ENI. 

resource "aws_network_interface" "enis_for_vsrx" {
  for_each = {
    for index, eni in local.enis_vsrx : "${eni.name}" => eni
  }
  subnet_id       = each.value.subnet_id
  security_groups = [each.value.sec_group_id]
  description     = each.value.name
  tags = {
    Name       = each.value.name
    created_by = local.created_by_w_prefix
  }

}

# EIP (# of AZ used for gateway per VPC * 2) 
## If you have 2 AZ where you deploy vSRX GW, then each AZ will need 2 EIP. You will have total of 
## 4 EIPs. 
## EIP - management subnet ENI >> Assigned to the instance default eni
## EIP - Internet Subnet ENI >> Assigned to the instance internet subnet eni 

resource "aws_eip" "vsrx_eip" {
  for_each = {
    for index, tag in local.eip_tags : tag.name => tag
  }
  tags = {
    "Name" = each.value.name

  }
}

# EIP Association
## EIP association for vsrx instance (for primary eni/fxp0)
resource "aws_eip_association" "eip_vsrx_fxp0" {

  for_each = {
    for index, ass in local.eip_vsrx_ass : "vsrx-eip-${index}" => ass
  }

  instance_id   = each.value.inst_id
  allocation_id = each.value.eip_id
}

## EIP association for network interface eni public subnet / ge-0/0/0 
resource "aws_eip_association" "eip_vsrx_eni-ge-0-0-0" {

  for_each = {
    for index, ass in local.eip_vsrx_ass : "vsrx-eip-eni-${index}" => ass
  }

  network_interface_id = each.value.eni_id_internet
  allocation_id        = each.value.eip_id_internet

}


# Network Interface to EC2Instance (VSRX) association
## ENI to vSRX association...  
### Lan and Internet ENI needs to be associated. 
resource "aws_network_interface_attachment" "eni-vsrx-ass" {
  for_each = {
    for index, ass in local.eni_vsrx_ass : index => ass
  }
  instance_id          = each.value.inst_id
  network_interface_id = each.value.eni_id
  device_index         = each.value.dev_index

  depends_on = [
    aws_eip_association.eip_vsrx_fxp0
  ]
  
}

# Route Table - 1 per subnet 
## Only Management and Internet subnet in both the AZ will have 0/0 route to internet gateway
## Private subnet - Lan subnet will have a default route pointing to the ENI of the vSRX instance belonging to the private subnet in that AZ. 

resource "aws_route_table" "vpc_rtbs" {

  for_each = toset(keys(aws_subnet.onprem_sim_subnet))
  vpc_id   = aws_vpc.onprem_sim_vpc.id
  tags = {
    Name       = "${each.key}-rtb"
    Created_by = local.created_by_w_prefix
  }
}

resource "aws_route" "vpc_rtbs_lan_routes" {
  for_each               = {
   for key_name , vpc_rtb in aws_route_table.vpc_rtbs : key_name => vpc_rtb if element(split(".", key_name), length(split(".", key_name)) - 1) == "lan"
  }
  route_table_id         = each.value.id
  destination_cidr_block = local.all_ip[0]
  network_interface_id   = aws_network_interface.enis_for_vsrx["${element(split(".", each.key), length(split(".", each.key)) - 2)}-lan-eni"].id
}

resource "aws_route" "vpc_rtbs_int_mgmt_routes" {
  for_each               = {
   for key_name , vpc_rtb in aws_route_table.vpc_rtbs : key_name => vpc_rtb if element(split(".", key_name), length(split(".", key_name)) - 1) != "lan"
  }

  route_table_id         = each.value.id
  destination_cidr_block = local.all_ip[0]
  gateway_id             = aws_internet_gateway.internetgw.id
}
  
# RTB and Subnet Association

resource "aws_route_table_association" "vsrx_sub_rtb_ass" {
   
    for_each = aws_subnet.onprem_sim_subnet 
    subnet_id = each.value.id 
    route_table_id = aws_route_table.vpc_rtbs[each.key].id 

}



#### Need to work on the logic below #####
# Jump host to ssh into the test instances and associated security group
# Will be deployed in the management subnet

resource "aws_instance" "ec2_jmp_host" {
  
  ami                         = var.test_inst_ami
  instance_type               = var.jump_host_instance_type
  subnet_id                   = aws_subnet.onprem_sim_subnet["${local.vpc_name_w_prefix}.${local.azs[0]}.management"].id
  vpc_security_group_ids      = [aws_security_group.jump_host_ssh.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  tags = {
    Name = "${local.vpc_name_w_prefix}-jump_host"
  } 
}

resource "aws_security_group" "jump_host_ssh" {
  
  name     = "jump_host_ssh"
  vpc_id   = aws_vpc.onprem_sim_vpc.id
  ingress {
    from_port   = local.ssh_port
    to_port     = local.ssh_port
    protocol    = local.protocol_tcp
    cidr_blocks = local.all_ip
  }

 egress {
    from_port   = local.port_any
    to_port     = local.port_any
    protocol    = local.protocol_any
    cidr_blocks = local.all_ip
  }
}

# Test instance to generate traffic 
# Will be deployed in the LAN subnet 
# From the root module, user will need to input the number of instances and instance type
# That many instances will be deployed in each lan subnet per AZ in the region. 
# Default are set. 

resource "aws_instance" "ec2_test_inst" {
  
  for_each = {
    for test_inst in local.test_inst_info: test_inst.inst_name => test_inst 
  }
  ami                         = var.test_inst_ami
  instance_type               = var.test_instance_type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = [aws_security_group.test_inst_allow_all.id]
  key_name                    = var.key_name
  associate_public_ip_address = false
  tags = {
    Name = each.value.inst_name
    created_by = local.created_by_w_prefix

  } 
}

# Need to modify this later on
resource "aws_security_group" "test_inst_allow_all" {
  
  name     = "test_pvt_inst_allow_all"
  vpc_id   = aws_vpc.onprem_sim_vpc.id
 ingress {
    from_port   = local.port_any
    to_port     = local.port_any
    protocol    = local.protocol_any
    cidr_blocks = local.all_ip
  }
 egress {
    from_port   = local.port_any
    to_port     = local.port_any
    protocol    = local.protocol_any
    cidr_blocks = local.all_ip
  }
}


## Data Block 

data "aws_ssm_parameter" "vsrx_img_id" {
  name = var.vsrx_ami_ssm_name
}

data "aws_availability_zones" "az" {}
