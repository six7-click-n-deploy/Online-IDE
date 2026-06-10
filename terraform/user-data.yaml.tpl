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

# Dozenten-Materialien aus dem Wizard. Jeder Eintrag in
# ``assignment_files`` wurde im Backend base64-encodiert; cloud-init
# dekodiert das per ``encoding: b64`` und legt die Datei unter
# ``/opt/material/<original-name>`` ab. Das Verzeichnis wird allen
# Team-Usern lesbar gemacht (0644 + lesender Pfad).
%{ if length(assignment_files) > 0 ~}
write_files:
%{ for slot_key, file in assignment_files ~}
  - path: /opt/material/${file.name}
    content: ${file.content_b64}
    encoding: b64
    owner: root:root
    permissions: '0644'
%{ endfor ~}
%{ endif ~}

# code-server pro User als System-Service starten
# Jeder User bekommt eigenen code-server auf eigenem Port mit eigenem Passwort
runcmd:
%{ for user_id, user in users ~}
  # User ${user.username}: code-server auf Port ${lookup(user_ports, user_id, 8080)}
  - mkdir -p /home/${user.username}/.local/share/code-server
  - mkdir -p /home/${user.username}/.config/code-server
  - chown -R ${user.username}:${user.username} /home/${user.username}/.local
  - chown -R ${user.username}:${user.username} /home/${user.username}/.config
  - |
    cat > /home/${user.username}/.config/code-server/config.yaml << 'EOFCONFIG${user_id}'
    bind-addr: 0.0.0.0:${lookup(user_ports, user_id, 8080)}
    auth: password
    password: "${passwords[user_id]}"
    cert: false
    user-data-dir: /home/${user.username}/.local/share/code-server
    EOFCONFIG${user_id}
  - chown ${user.username}:${user.username} /home/${user.username}/.config/code-server/config.yaml
  - chmod 600 /home/${user.username}/.config/code-server/config.yaml
  - |
    cat > /etc/systemd/system/code-server-${user.username}.service << 'EOFSVC${user_id}'
    [Unit]
    Description=code-server for ${user.username}
    After=network.target

    [Service]
    Type=simple
    User=${user.username}
    WorkingDirectory=/home/${user.username}
    ExecStart=/usr/bin/code-server --config /home/${user.username}/.config/code-server/config.yaml
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    EOFSVC${user_id}
  - systemctl daemon-reload
  - systemctl enable code-server-${user.username}
  - systemctl start code-server-${user.username}
%{ endfor ~}

