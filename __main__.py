import pulumi
import pulumi_aws as aws
import pulumi_random as random

from modules.network import NetworkModule
from modules.security import SecurityModule
from modules.bastion import BastionModule
from modules.database import DatabaseModule

# ── CONFIG ────────────────────────────────────────────────────────────────────
config = pulumi.Config()
db_password    = config.require_secret("db_password")
ssh_public_key = config.require("ssh_public_key")

# ── NETWORK ───────────────────────────────────────────────────────────────────
network = NetworkModule("vasaloppet")

# ── SECURITY ──────────────────────────────────────────────────────────────────
security = SecurityModule("vasaloppet", vpc_id=network.vpc.id)

# ── BASTION ───────────────────────────────────────────────────────────────────
bastion = BastionModule(
    "vasaloppet",
    subnet_id=network.public_subnet.id,
    sg_id=security.bastion_sg.id,
    ssh_public_key=ssh_public_key,
)

# ── DATABASE ──────────────────────────────────────────────────────────────────
database = DatabaseModule(
    "vasaloppet",
    subnet_ids=[network.private_subnet.id, network.private_subnet_b.id],
    sg_id=security.db_sg.id,
    db_password=db_password,
)

# ── APP-MODULEN ÄR BORTTAGEN ──────────────────────────────────────────────────
# I Terraform-projektet körde app-servern containers från IBM Container
# Registry (icr.io) med IBM WatsonX-integration. Varken ICR eller WatsonX
# finns på AWS. App-modulen kan därför inte återskapas på ett meningsfullt
# sätt och är borttagen från Pulumi-implementationen.
# Se diskussionsavsnittet i rapporten.

# ── S3 BUCKETS ────────────────────────────────────────────────────────────────
bucket_suffix = random.RandomId("bucket-suffix", byte_length=4)

logs_data_bucket = aws.s3.Bucket(
    "vasaloppet-logs-data",
    bucket=pulumi.Output.concat("vasaloppet-logs-data-", bucket_suffix.hex),
    force_destroy=True,
    tags={"Name": "vasaloppet-logs-data"},
)

logs_metrics_bucket = aws.s3.Bucket(
    "vasaloppet-logs-metrics",
    bucket=pulumi.Output.concat("vasaloppet-logs-metrics-", bucket_suffix.hex),
    force_destroy=True,
    tags={"Name": "vasaloppet-logs-metrics"},
)

# ── CLOUDWATCH ────────────────────────────────────────────────────────────────
log_group = aws.cloudwatch.LogGroup(
    "vasaloppet-log-group",
    name="/vasaloppet/app",
    retention_in_days=7,
    tags={"Name": "vasaloppet-logs"},
)

# ── IAM ───────────────────────────────────────────────────────────────────────
cloudwatch_role = aws.iam.Role(
    "vasaloppet-cw-role",
    assume_role_policy="""{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "logs.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }""",
)

aws.iam.RolePolicy(
    "vasaloppet-cw-s3-policy",
    role=cloudwatch_role.id,
    policy=pulumi.Output.all(
        logs_data_bucket.arn,
        logs_metrics_bucket.arn,
    ).apply(lambda arns: f"""{{
        "Version": "2012-10-17",
        "Statement": [{{
            "Effect": "Allow",
            "Action": ["s3:PutObject", "s3:GetBucketAcl"],
            "Resource": ["{arns[0]}/*", "{arns[1]}/*"]
        }}]
    }}"""),
)

# ── OUTPUTS ───────────────────────────────────────────────────────────────────
pulumi.export("vpc_id",              network.vpc.id)
pulumi.export("bastion_public_ip",   bastion.instance.public_ip)
pulumi.export("db_endpoint",         database.instance.endpoint)
pulumi.export("db_address",          database.instance.address)
pulumi.export("db_port",             database.instance.port)
pulumi.export("db_name",             database.instance.db_name)
pulumi.export("db_user",             database.instance.username)
pulumi.export("logs_data_bucket",    logs_data_bucket.id)
pulumi.export("logs_metrics_bucket", logs_metrics_bucket.id)
pulumi.export("log_group",           log_group.name)