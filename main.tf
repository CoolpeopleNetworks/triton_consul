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
        common_name  = "consul.local"
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
    name = "debian-9-cloudinit"
    version = "1.0.0"
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

    cloud_config = templatefile("${path.module}/cloud-config.yml.tpl", {
        dns_suffix = var.config.network.domain_name,
        datacenter_name = var.config.network.datacenter_name
        retry_join = "consul.svc.${data.triton_account.main.id}.${var.config.network.cns_suffix}"
        server_replicas = var.config.server_replicas
        encryption_key = random_id.encryption_key.b64_std

        ca_certificate = var.config.certificate_authority.certificate_pem
        certificate = tls_locally_signed_cert.consul[count.index].cert_pem
        private_key = tls_private_key.consul[count.index].private_key_pem
        master_token = var.config.master_token
        upstream_dns_server = var.config.network.dns_server
    })
}

output "consul_master_token" {
    sensitive = true
    value = var.config.master_token
}
