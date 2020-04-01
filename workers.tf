module "workers" {
  source       = "./workers"
  name         = var.cluster_name
  cluster_name = var.cluster_name

  # GCE
  region       = var.region
  network      = google_compute_network.network.name
  worker_count = var.worker_count
  machine_type = var.worker_type
  os_image     = var.os_image
  disk_size    = var.disk_size
  preemptible  = var.worker_preemptible

  # configuration
  kubeconfig            = module.bootstrap.kubeconfig-kubelet
  ssh_authorized_key    = var.ssh_authorized_key
  service_cidr          = var.service_cidr
  cluster_domain_suffix = var.cluster_domain_suffix
  snippets              = var.worker_snippets
  node_labels           = var.worker_node_labels
}

