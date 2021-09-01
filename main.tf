locals {
    consul_version="1.10.1"
}

data "triton_account" "main" {}

# Create the Consul certificates
resource "tls_private_key" "consul" {
    count = var.config.server_replicas
    algorithm = "RSA"
    rsa_bits  = "4096"
}

# Create the request to sign the cert with our CA
resource "tls_cert_request" "consul-req" {
    count = var.config.server_replicas
    key_algorithm   = tls_private_key.consul[count.index].algorithm
    private_key_pem = tls_private_key.consul[count.index].private_key_pem

    dns_names = [
        "consul",
        "consul.local",
        "consul.default.svc.cluster.local",
        "server.${var.config.network.datacenter_name}.consul",
        "consul.service.${var.config.network.domain_name}",
    ]

    subject {
        common_name = "server.${var.config.network.datacenter_name}.consul"
        organization = var.config.organization.name
    }
}

resource "tls_locally_signed_cert" "consul" {
    count = var.config.server_replicas
    cert_request_pem = tls_cert_request.consul-req[count.index].cert_request_pem

    ca_key_algorithm   = var.config.certificate_authority.algorithm
    ca_private_key_pem = var.config.certificate_authority.private_key_pem
    ca_cert_pem        = var.config.certificate_authority.certificate_pem

    validity_period_hours = 8760

    allowed_uses = [
        "cert_signing",
        "client_auth",
        "digital_signature",
        "key_encipherment",
        "server_auth",
    ]
}

resource "random_id" "encryption_key" {
    byte_length = 32
}

data "triton_image" "os" {
    name = "base-64-lts"
    version = "20.4.0"
}

resource "triton_machine" "consul" {
    count = var.config.server_replicas
    name = "consul-${count.index}"
    package = var.config.server_package

    image = data.triton_image.os.id

    cns {
        services = ["consul"]
    }

    networks = [
        data.triton_network.private.id
    ]

    tags = {
        consul-role = "server"
    }
    
    affinity = ["consul-role!=~server"]

    connection {
        host = self.primaryip
    }

    provisioner "remote-exec" {
        inline = [
            "mkdir -p /opt/local/etc/consul.d/certificates",
            "mkdir -p /opt/local/consul",
            "useradd -d /opt/local/consul consul",
            "groupadd consul",
            "chown consul /opt/local/consul",
            "chgrp consul /opt/local/consul",
        ]
    } 

    provisioner "file" {
        content = var.config.certificate_authority.certificate_pem
        destination = "/opt/local/etc/consul.d/certificates/ca.pem"
    }

    provisioner "file" {
        content = tls_locally_signed_cert.consul[count.index].cert_pem
        destination = "/opt/local/etc/consul.d/certificates/cert.pem"
    }

    provisioner "file" {
        content = tls_private_key.consul[count.index].private_key_pem
        destination = "/opt/local/etc/consul.d/certificates/private_key.pem"
    }

    provisioner "file" {
        source = "${path.module}/consul.xml"
        destination = "/opt/consul.xml"
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/consul.hcl.tpl", {
            datacenter_name = var.config.network.datacenter_name,
            domain_name = var.config.network.domain_name,
            node_name = "consul-${count.index}",
            bootstrap_expect = var.config.server_replicas,
            rejoin_addresses = ["consul.svc.${data.triton_account.main.id}.${var.config.network.cns_suffix}"],
            encryption_key = random_id.encryption_key.b64_std,
            upstream_dns_servers = var.config.network.dns_servers,
        })
        destination = "/opt/local/etc/consul.d/consul.hcl"
    }

    provisioner "remote-exec" {
        inline = [
            "svcadm disable inetd", # Disable inetd since consul will need to run on DNS port 53.
            "pkgin -y update",
            "pkgin -y in wget unzip",
            "cd /tmp ; wget --no-check-certificate https://releases.hashicorp.com/consul/${local.consul_version}/consul_${local.consul_version}_solaris_amd64.zip",
            "cd /tmp ; unzip consul_${local.consul_version}_solaris_amd64.zip",
            "cd /tmp ; rm consul_${local.consul_version}_solaris_amd64.zip",

            "mv /tmp/consul /opt/local/bin/consul",

            "svccfg import /opt/consul.xml",
        ]
    }
}

output "consul_encryption_key" {
    sensitive = true
    value = random_id.encryption_key.b64_std
}
