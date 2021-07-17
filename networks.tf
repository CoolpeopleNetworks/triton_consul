data "triton_network" "public" {
  name = "sdc_nat"
}

data "triton_network" "private" {
  name = "My-Fabric-Network"
}
