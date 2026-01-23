#cloud-config

# Team-Gruppen erstellen
groups:
%{ for team in teams ~}
  - ${team}
%{ endfor ~}

# User-Accounts erstellen
users:
%{ for user_id, user in users ~}
  - name: ${user.username}
    groups: ${user.team}
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
%{ endfor ~}

# Passwörter setzen
chpasswd:
  list: |
%{ for user_id, user in users ~}
    ${user.username}:${passwords[user_id]}
%{ endfor ~}
  expire: false

# SSH Passwort-Authentifizierung aktivieren
ssh_pwauth: true

# code-server pro User als System-Service starten
# Jeder User bekommt eigenen code-server auf eigenem Port mit eigenem Passwort
runcmd:
%{ for idx, user_id in keys(users) ~}
  # User ${users[user_id].username}: code-server auf Port ${8080 + idx}
  - mkdir -p /home/${users[user_id].username}/.local/share/code-server
  - mkdir -p /home/${users[user_id].username}/.config/code-server
  - chown -R ${users[user_id].username}:${users[user_id].username} /home/${users[user_id].username}/.local
  - chown -R ${users[user_id].username}:${users[user_id].username} /home/${users[user_id].username}/.config
  - |
    cat > /home/${users[user_id].username}/.config/code-server/config.yaml << 'EOFCONFIG${idx}'
    bind-addr: 0.0.0.0:${8080 + idx}
    auth: password
    password: ${passwords[user_id]}
    cert: false
    user-data-dir: /home/${users[user_id].username}/.local/share/code-server
    EOFCONFIG${idx}
  - chown ${users[user_id].username}:${users[user_id].username} /home/${users[user_id].username}/.config/code-server/config.yaml
  - chmod 600 /home/${users[user_id].username}/.config/code-server/config.yaml
  - |
    cat > /etc/systemd/system/code-server-${users[user_id].username}.service << 'EOFSVC${idx}'
    [Unit]
    Description=code-server for ${users[user_id].username}
    After=network.target

    [Service]
    Type=simple
    User=${users[user_id].username}
    WorkingDirectory=/home/${users[user_id].username}
    ExecStart=/usr/bin/code-server --config /home/${users[user_id].username}/.config/code-server/config.yaml
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    EOFSVC${idx}
  - systemctl daemon-reload
  - systemctl enable code-server-${users[user_id].username}
  - systemctl start code-server-${users[user_id].username}
%{ endfor ~}

