output "vsrx_info" {
  value = aws_instance.vsrxs
  description = "All vSRX/Instance attributes as map for all instances "
}

output "vsrx_eip" {
  description = "All attributes EIPs/Public created for vsrx"
  value = aws_eip.vsrx_eip
}

output "vsrx_eni" {
  description = "All attributes for ENI associated with vsrx"
  value = aws_network_interface.enis_for_vsrx
}

output "jump_host_info" {
  value = aws_instance.ec2_jmp_host
  description = "All jump_host/instance attributes"
}

output "vpc_info" {
  value = aws_vpc.onprem_sim_vpc
  description = "All VPC related attributes"
}

output "subnet_info" {
  value = aws_subnet.onprem_sim_subnet
  description = "All subnets attributes under the VPC"
}

output "azs_used" {
  value = local.azs  
  description = "AZs in which vSRX are deployed"
}

output "test_instance_info" {
  value = aws_instance.ec2_test_inst
  description = "All test instances attributes as map for all instances"
}