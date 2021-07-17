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
        retry_join = "provider=triton account=${var.triton_account} url=${var.triton_api_url} key_id=${var.triton_key_id} tag_key=consul-role tag_value=server",
        server_replicas = var.server_replicas
    })
}
