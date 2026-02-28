\# Add "Update Kasm" to Proxmox GUI



To add a custom “Update Kasm” button in the Proxmox GUI:



1\. Edit the file:

&nbsp;  `/usr/share/pve-manager/ext6/pvemanagerlib.js`



2\. Find the section for LXC menu actions:

&nbsp;  `Ext.define('PVE.lxc.Config', { ... })`



3\. Add this entry inside the `items` array:



{

&nbsp;   text: 'Update Kasm',

&nbsp;   handler: function() {

&nbsp;       PVE.Utils.API2Request({

&nbsp;           url: '/nodes/' + nodename + '/lxc/' + vmid + '/status/custom',

&nbsp;           method: 'POST',

&nbsp;           params: {

&nbsp;               command: '/scripts/kasm-lxc-gui-wrapper.sh ' + vmid

&nbsp;           }

&nbsp;       });

&nbsp;   }

}



4\. Save the file and reload the Proxmox GUI.



