# Ansible Playbooks for CageLab

Ansible is an automation tool that allows for the remote execution of commands and the management of multiple remote systems. For CageLab, it is used to manage the remote cagelab nodes, to ensure software is up-to-date and consistent across devices. You will need to edit the inventory/hosts file to add or remove nodes from the inventory. The playbooks are located in the playbooks directory and can be run using the `ansible-playbook` command. You must edit the [hosts](inventory/hosts) inventory to point to your hosts/IPs for your CageLab devices.

## Example command:

This will run an `update` on all cagelab devices specified in the cagelab_servers inventory asking for the sudo password before running the tasks across all nodes.

```shell 
ansible-playbook --limit cagelab_servers --ask-become-pass  ansible/playbooks/update.yaml
```

## Playbooks: 

* [reset_code](playbooks/reset_code.yaml) — force reset CageLab code repositories to the latest version from https://gitee.com
* [update](playbooks/update.yaml) — full update to dtop cagelab services, reset all code repositories to the latest versions even if local changes were made, update cogmoteGO, mediamtx and OBS Studio, and restart the services.
* [install_i3](playbooks/install_i3.yaml) — i3 is a tiling window manager that allows us to remove all "clickable" UI so subjects only see a desktop before a task starts, and also it runs PTB faster with less issues due to Ubuntu's compositor.
* [check_api_status](playbooks/check_api_status.yaml) — uses cogmoteGO's status API to check if a task is running or not.
* [services-stop](playbooks/services-stop.yaml) & [services-start](playbooks/services-start.yaml) — stop / start CageLAb services