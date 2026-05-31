import pulumi
import pulumi_aws as aws


class DatabaseModule(pulumi.ComponentResource):
    def __init__(
        self,
        name: str,
        subnet_ids,
        sg_id,
        db_password: str,
        opts=None,
    ):
        super().__init__("vasaloppet:modules:Database", name, {}, opts)

        # ── RDS SUBNET GROUP ───────────────────────────────────────────
        self.subnet_group = aws.rds.SubnetGroup(
            f"{name}-db-subnet-group",
            subnet_ids=subnet_ids,
            tags={"Name": f"{name}-db-subnet-group"},
            opts=pulumi.ResourceOptions(parent=self),
        )

    
        self.instance = aws.rds.Instance(
            f"{name}-postgres",
            engine="postgres",
            engine_version="15",
            instance_class="db.t3.micro",
            allocated_storage=20,
            db_name="vasaloppetdb",
            username="dbadmin",
            password=db_password,
            db_subnet_group_name=self.subnet_group.name,
            vpc_security_group_ids=[sg_id],
            publicly_accessible=False,   
            skip_final_snapshot=True,
            apply_immediately=True,
            tags={"Name": f"{name}-postgres"},
            opts=pulumi.ResourceOptions(parent=self),
        )

        self.register_outputs({
            "endpoint": self.instance.endpoint,
            "address": self.instance.address,
            "port": self.instance.port,
            "db_name": self.instance.db_name,
            "username": self.instance.username,
        })