data "triton_account" "main" {}

resource "random_id" "encryption_key" {
    byte_length = 32
}

data "triton_image" "os" {
    name = "debian-9-cloudinit"
    version = "1.0.0"
}

resource "triton_machine" "consul" {
    count = var.server_replicas
    name = "consul-${count.index}"
    package = var.server_package

    image = data.triton_image.os.id

    cns {
        services = ["consul"]
    }

    networks = [
        data.triton_network.public.id,
        data.triton_network.private.id
    ]

    tags = {
        consul-role = "server"
    }
    
    cloud_config = templatefile("${path.module}/cloud-config.yml.tpl", {
        consul_nic_tag = var.consul_nic_tag
        dns_suffix = var.dns_suffix,
        datacenter_name = var.datacenter_name
        retry_join = "consul.svc.${data.triton_account.main.id}.${var.cns_suffix}"
        server_replicas = var.server_replicas
        encryption_key = random_id.encryption_key.b64_std
    })
}
