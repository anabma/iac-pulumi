import pulumi
import pulumi_aws as aws


class NetworkModule(pulumi.ComponentResource):
    def __init__(self, name: str, opts=None):
        super().__init__("client:modules:Network", name, {}, opts)

        # VPC
        self.vpc = aws.ec2.Vpc(
            f"{name}-vpc",
            cidr_block="10.0.0.0/16",
            enable_dns_hostnames=True,
            enable_dns_support=True,
            tags={"Name": f"{name}-vpc"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        # Public subnet - eu-north-1a
        self.public_subnet = aws.ec2.Subnet(
            f"{name}-public-subnet",
            vpc_id=self.vpc.id,
            cidr_block="10.0.1.0/24",
            availability_zone="eu-north-1a",
            map_public_ip_on_launch=True,
            tags={"Name": f"{name}-public-subnet"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        # Private subnet - eu-north-1a (app och db)
        self.private_subnet = aws.ec2.Subnet(
            f"{name}-private-subnet",
            vpc_id=self.vpc.id,
            cidr_block="10.0.2.0/24",
            availability_zone="eu-north-1a",
            map_public_ip_on_launch=False,
            tags={"Name": f"{name}-private-subnet"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        # Extra subnet 
        self.private_subnet_b = aws.ec2.Subnet(
            f"{name}-private-subnet-b",
            vpc_id=self.vpc.id,
            cidr_block="10.0.3.0/24",
            availability_zone="eu-north-1b",
            map_public_ip_on_launch=False,
            tags={"Name": f"{name}-private-subnet-b"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        # Internet Gateway
        self.igw = aws.ec2.InternetGateway(
            f"{name}-igw",
            vpc_id=self.vpc.id,
            tags={"Name": f"{name}-igw"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        # Route table for public subnet
        self.public_rt = aws.ec2.RouteTable(
            f"{name}-public-rt",
            vpc_id=self.vpc.id,
            routes=[aws.ec2.RouteTableRouteArgs(
                cidr_block="0.0.0.0/0",
                gateway_id=self.igw.id,
            )],
            tags={"Name": f"{name}-public-rt"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        aws.ec2.RouteTableAssociation(
            f"{name}-public-rta",
            subnet_id=self.public_subnet.id,
            route_table_id=self.public_rt.id,
            opts=pulumi.ResourceOptions(parent=self),
        )

        # NAT Gateway for private subnets
        self.eip = aws.ec2.Eip(
            f"{name}-nat-eip",
            tags={"Name": f"{name}-nat-eip"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        self.nat_gw = aws.ec2.NatGateway(
            f"{name}-nat-gw",
            subnet_id=self.public_subnet.id,
            allocation_id=self.eip.id,
            tags={"Name": f"{name}-nat-gw"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        # Route table for private subnets
        self.private_rt = aws.ec2.RouteTable(
            f"{name}-private-rt",
            vpc_id=self.vpc.id,
            routes=[aws.ec2.RouteTableRouteArgs(
                cidr_block="0.0.0.0/0",
                nat_gateway_id=self.nat_gw.id,
            )],
            tags={"Name": f"{name}-private-rt"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        aws.ec2.RouteTableAssociation(
            f"{name}-private-rta",
            subnet_id=self.private_subnet.id,
            route_table_id=self.private_rt.id,
            opts=pulumi.ResourceOptions(parent=self),
        )

        aws.ec2.RouteTableAssociation(
            f"{name}-private-rta-b",
            subnet_id=self.private_subnet_b.id,
            route_table_id=self.private_rt.id,
            opts=pulumi.ResourceOptions(parent=self),
        )

        self.register_outputs({
            "vpc_id": self.vpc.id,
            "public_subnet_id": self.public_subnet.id,
            "private_subnet_id": self.private_subnet.id,
            "private_subnet_b_id": self.private_subnet_b.id,
        })
