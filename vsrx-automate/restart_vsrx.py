#!/Library/Frameworks/Python.framework/Versions/3.10/bin/python3
import os
import subprocess
import json 

# List of commands for TF
cmd_vsrx_instance = "terraform output -json vsrx_instance_ids"


def get_tf_output_frm_cli(cmd):
    
    os.chdir("../")
    tf_op = subprocess.run(cmd.split(),capture_output=True,text=True)
    """ print(tf_op.stdout)
    print(tf_op.args)
    print(tf_op.returncode)
    print(tf_op.stderr) """
    return json.loads(tf_op.stdout)
    #print(vsrx_id)

def reboot_vsrx_aws(vsrx_ids):
    rs_aws_inst_cmd = "aws ec2 reboot-instances --instance-ids" 
    profile = aws_creds_profile_name
    region = aws_region

    for key , value in vsrx_ids.items():
        print(f'\nRestarting {key} with instance_id : {value} ')
        cmd1 = f'{rs_aws_inst_cmd} {value} --profile {profile} --region {region}' 
        op = subprocess.run(cmd1.split(),capture_output=True,text=True)

"""     print(cmd1)
        print(op.stdout)
        print(op.stderr)
"""
if __name__=="__main__":

    print("\nThis program will fetch the Juniper vsrx instance ids from the tf output and restart them using\n aws cli \n")
    
    aws_creds_profile_name = input("Pleae enter your aws credentials file profile name to use: \n")
    aws_region = input("Please enter aws region to issue these commands: \n")
    
    vsrx_inst_ids = get_tf_output_frm_cli(cmd_vsrx_instance)
    reboot_vsrx_aws(vsrx_inst_ids)


    


