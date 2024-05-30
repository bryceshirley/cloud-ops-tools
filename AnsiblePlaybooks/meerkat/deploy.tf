terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
    ansible = {
      source = "ansible/ansible"
      # No version constraint specified
    }
  }
}

provider "openstack" {
  cloud = "openstack"	# Uses the section called “openstack” from our app creds
}

##############################################################################
### Deploy VM instances
##############################################################################

locals {
  my_product = {for val in setproduct(var.flavor_name, var.image_name):
    "${val[0]}-${val[1]}" => val}
}

resource "openstack_compute_instance_v2" "Instance" {
  for_each = local.my_product
  name = "${var.instance_name}-${each.value[0]}-${each.value[1]}"
  image_name = each.value[1]
  flavor_name = each.value[0]
  key_pair = var.keypair_name
  security_groups = var.security_groups
  network {
    name = var.network_name
  }
  metadata = {
    group = var.VM_group
  }
}

locals {
  vm_ids = [ for val in openstack_compute_instance_v2.Instance : val.id]
  vm_names = [ for val in openstack_compute_instance_v2.Instance : val.name]
  vm_ips = [for val in openstack_compute_instance_v2.Instance : val.access_ip_v4]
}

##############################################################################
### Deploy manila shares
##############################################################################
resource "openstack_sharedfilesystem_share_v2" "share" {
  name             = "meerkat"
  description      = "manila terraform share"
  share_proto      = "CEPHFS"
  size             = var.share_size * length(openstack_compute_instance_v2.Instance)
}

resource "openstack_sharedfilesystem_share_access_v2" "share_access" {
  share_id     = openstack_sharedfilesystem_share_v2.share.id
  access_type  = "cephx"
  access_to    = "${var.user}"
  access_level = "rw"
}



##############################################################################
### Deploy volume storage
##############################################################################
resource "openstack_blockstorage_volume_v3" "volumes" {
  count = var.deploy_volume * length(local.my_product)
  name = format("vol-%02d", count.index + 1)
  region = "RegionOne"
  description = "volume for benchmark testing"
  size = var.volume_size
}

locals {
  volume_ids = [ for val in openstack_blockstorage_volume_v3.volumes : val.id]
}

resource "openstack_compute_volume_attach_v2" "vol_attach" {
  count = var.deploy_volume * length(openstack_compute_instance_v2.Instance)
  instance_id = local.vm_ids[count.index]
  volume_id = local.volume_ids[count.index]
}


##############################################################################
### Run ansible playbook
##############################################################################
resource "null_resource" "ansible_playbook" {
  depends_on = [openstack_compute_instance_v2.Instance, openstack_sharedfilesystem_share_v2.share, openstack_sharedfilesystem_share_access_v2.share_access, openstack_blockstorage_volume_v3.volumes, openstack_compute_volume_attach_v2.vol_attach]
  count = length(openstack_compute_instance_v2.Instance)
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i staging-openstack.yaml -l ${local.vm_names[count.index]} ${var.playbook_path} --extra-vars 'share_path=${openstack_sharedfilesystem_share_v2.share.export_locations[0].path} access_key=${openstack_sharedfilesystem_share_access_v2.share_access.access_key} vm_count=${count.index}'"
  }
}

