cat > scripts/kasm-lxc-gui-wrapper.sh << 'EOF'
#!/bin/bash
CTID=$1
/scripts/kasm-lxc-auto-update.sh "$CTID" --notify-none
EOF
