# Discrete DNS records for each controller's private IPv4 for etcd usage
resource "google_dns_record_set" "etcds" {
  count = var.controller_count

  # DNS Zone name where record should be created
  managed_zone = var.dns_zone_name

  # DNS record
  name = format("%s-etcd%d.%s.", var.cluster_name, count.index, var.dns_zone)
  type = "A"
  ttl  = 300

  # private IPv4 address for etcd
  rrdatas = [google_compute_instance.controllers.*.network_interface.0.network_ip[count.index]]
}

# Zones in the region
data "google_compute_zones" "all" {
  region = var.region
}

locals {
  zones = data.google_compute_zones.all.names

  controllers_ipv4_public = google_compute_instance.controllers.*.network_interface.0.access_config.0.nat_ip
}

# Controller instances
resource "google_compute_instance" "controllers" {
  count = var.controller_count

  name = "${var.cluster_name}-controller-${count.index}"
  # use a zone in the region and wrap around (e.g. controllers > zones)
  zone         = element(local.zones, count.index)
  machine_type = var.controller_type

  metadata = {
    user-data = data.ct_config.controller-ignitions.*.rendered[count.index]
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image = var.os_image
      size  = var.disk_size
    }
  }

  network_interface {
    network = google_compute_network.network.name

    # Ephemeral external IP
    access_config {
    }
  }

  can_ip_forward = true
  tags           = ["${var.cluster_name}-controller"]

  lifecycle {
    ignore_changes = [metadata]
  }
}

# Controller Ignition configs
data "ct_config" "controller-ignitions" {
  count    = var.controller_count
  content  = data.template_file.controller-configs.*.rendered[count.index]
  strict   = true
  snippets = var.controller_snippets
}

# Controller Container Linux configs
data "template_file" "controller-configs" {
  count = var.controller_count

  template = file("${path.module}/cl/controller.yaml")

  vars = {
    # Cannot use cyclic dependencies on controllers or their DNS records
    etcd_name   = "etcd${count.index}"
    etcd_domain = "${var.cluster_name}-etcd${count.index}.${var.dns_zone}"
    # etcd0=https://cluster-etcd0.example.com,etcd1=https://cluster-etcd1.example.com,...
    etcd_initial_cluster   = join(",", data.template_file.etcds.*.rendered)
    kubeconfig             = indent(10, module.bootstrap.kubeconfig-kubelet)
    ssh_authorized_key     = var.ssh_authorized_key
    cluster_dns_service_ip = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix  = var.cluster_domain_suffix
  }
}

data "template_file" "etcds" {
  count    = var.controller_count
  template = "etcd$${index}=https://$${cluster_name}-etcd$${index}.$${dns_zone}:2380"

  vars = {
    index        = count.index
    cluster_name = var.cluster_name
    dns_zone     = var.dns_zone
  }
}

