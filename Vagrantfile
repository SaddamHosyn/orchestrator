# K3s Kubernetes Cluster on Vagrant - VirtualBox Provider
# Two VMs: Master (K3s server) and Agent (K3s worker)
# This orchestrates microservices deployment on a Kubernetes cluster

Vagrant.configure("2") do |config|
  # Ubuntu 24.04 ARM64 - same box as CRUD-MASTER project (proven working)
  config.vm.box = "hashicorp-education/ubuntu-24-04"
  config.vm.synced_folder "./", "/home/vagrant/project"

  # ============================================================
  # VM 1: MASTER (K3s Server Node)
  # ============================================================
  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
    master.vm.provision "shell", path: "Scripts/master.sh"
  end

  # ============================================================
  # VM 2: AGENT (K3s Worker Node)
  # ============================================================
  config.vm.define "agent" do |agent|
    agent.vm.hostname = "agent"
    agent.vm.network "private_network", ip: "192.168.56.11"
    agent.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
    agent.vm.provision "shell", path: "Scripts/agent.sh"
  end
end