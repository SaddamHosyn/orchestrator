# K3s Kubernetes Cluster on Vagrant - VirtualBox Provider
# Two VMs: Master (K3s server) and Agent (K3s worker)
# This orchestrates microservices deployment on a Kubernetes cluster
#
# MEMORY BUDGET (16GB host):
#   Master: 3072MB | Agent: 2048MB | Total VMs: 5GB | macOS: ~11GB free
#
# BOOT ORDER: Always boot master first, then agent (never simultaneously)
#   vagrant up master && vagrant up agent
#
# DAILY WORKFLOW:
#   Start: vagrant up master --no-provision && vagrant up agent --no-provision
#   Stop:  vagrant halt agent && vagrant halt master
#   Nuke:  pkill -9 VBoxHeadless; pkill -9 VBoxSVC

Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp-education/ubuntu-24-04"
  config.vm.synced_folder "./", "/home/vagrant/project"

  # ============================================================
  # VM 1: MASTER (K3s Server Node)
  # Memory reduced 4096 -> 3072 to prevent macOS OOM on 16GB host
  # expand-disk.sh disabled (run: "never") — was crashing provisioning
  # ============================================================
  config.vm.define "master", primary: true do |master|
    master.vm.hostname = "master"
    master.vm.network "forwarded_port", guest: 22, host: 2223, auto_correct: true, id: "ssh"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "3072"
      vb.cpus = 2
      vb.linked_clone = true
    end
    master.vm.provision "shell", path: "Scripts/master.sh"
    master.vm.provision "shell", path: "Scripts/expand-disk.sh", run: "never"
    master.vm.provision "shell", path: "Scripts/add-swap.sh"
  end

  # ============================================================
  # VM 2: AGENT (K3s Worker Node)
  # expand-disk.sh disabled (run: "never") — was crashing provisioning
  # ============================================================
  config.vm.define "agent" do |agent|
    agent.vm.hostname = "agent"
    agent.vm.network "forwarded_port", guest: 22, host: 2200, auto_correct: true, id: "ssh"
    agent.vm.network "private_network", ip: "192.168.56.11"
    agent.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 1
      vb.linked_clone = true
    end
    agent.vm.provision "shell", path: "Scripts/agent.sh"
    agent.vm.provision "shell", path: "Scripts/expand-disk.sh", run: "never"
    agent.vm.provision "shell", path: "Scripts/add-swap.sh"
  end
end