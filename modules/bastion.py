import pulumi
import pulumi_aws as aws


class BastionModule(pulumi.ComponentResource):
    def __init__(
        self,
        name: str,
        subnet_id,
        sg_id,
        ssh_public_key: str,
        opts=None,
    ):
        super().__init__("client:modules:Bastion", name, {}, opts)

    
        self.key_pair = aws.ec2.KeyPair(
            f"{name}-key",
            public_key=ssh_public_key,
            tags={"Name": f"{name}-bastion-key"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        
        ami = aws.ec2.get_ami(
            most_recent=True,
            owners=["amazon"],
            filters=[aws.ec2.GetAmiFilterArgs(
                name="name",
                values=["amzn2-ami-hvm-*-x86_64-gp2"],
            )],
        )

        
        self.instance = aws.ec2.Instance(
            f"{name}-bastion",
            instance_type="t3.micro",
            ami=ami.id,
            subnet_id=subnet_id,
            vpc_security_group_ids=[sg_id],
            key_name=self.key_pair.key_name,
            associate_public_ip_address=True,
            tags={"Name": f"{name}-bastion"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        self.register_outputs({
            "instance_id": self.instance.id,
            "public_ip": self.instance.public_ip,
            "key_name": self.key_pair.key_name,
        })
