import urllib.request
import pulumi
import pulumi_aws as aws


def _get_my_ip() -> str:
    try:
        with urllib.request.urlopen("https://ifconfig.me/ip", timeout=5) as r:
            return r.read().decode().strip()
    except Exception:
        return "0.0.0.0"


class SecurityModule(pulumi.ComponentResource):
    def __init__(self, name: str, vpc_id, opts=None):
        super().__init__("client:modules:Security", name, {}, opts)

        my_ip = _get_my_ip()

        # Bastion - SSH bara från din IP
        self.bastion_sg = aws.ec2.SecurityGroup(
            f"{name}-bastion-sg",
            vpc_id=vpc_id,
            description="Bastion - SSH only from your IP",
            ingress=[aws.ec2.SecurityGroupIngressArgs(
                protocol="tcp", from_port=22, to_port=22,
                cidr_blocks=[f"{my_ip}/32"],
                description=f"SSH from {my_ip}",
            )],
            egress=[aws.ec2.SecurityGroupEgressArgs(
                protocol="-1", from_port=0, to_port=0,
                cidr_blocks=["0.0.0.0/0"],
            )],
            tags={"Name": f"{name}-bastion-sg"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        self.db_sg = aws.ec2.SecurityGroup(
            f"{name}-db-sg",
            vpc_id=vpc_id,
            description="RDS - PostgreSQL from bastion only",
            ingress=[
                aws.ec2.SecurityGroupIngressArgs(
                    protocol="tcp", from_port=5432, to_port=5432,
                    security_groups=[self.bastion_sg.id],
                    description="PostgreSQL from bastion",
                ),
            ],
            egress=[aws.ec2.SecurityGroupEgressArgs(
                protocol="-1", from_port=0, to_port=0,
                cidr_blocks=["0.0.0.0/0"],
            )],
            tags={"Name": f"{name}-db-sg"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        self.register_outputs({})
