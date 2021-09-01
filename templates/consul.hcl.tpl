{
    "datacenter": "${datacenter_name}",
    "data_dir": "/opt/local/consul",
    "log_level": "INFO",
    "node_name": "${node_name}",
    "server": true,
    "bootstrap_expect": ${bootstrap_expect},
    "addresses": { 
        "https": "0.0.0.0" 
    },
    "ports": { 
        "http": -1,
        "https": 8501 
    },
    "ui_config": {
        "enabled": true
    },
    "telemetry": { 
        "disable_compat_1.9": true 
    },
    "encrypt": "${encryption_key}",
    "bind_addr": "0.0.0.0",
    "client_addr": "0.0.0.0",
    "retry_join": ${jsonencode(rejoin_addresses)},
    "alt_domain": "${domain_name}",
    "dns_config": {
        "enable_truncate": true,
        "udp_answer_limit": 100,
    },
    "recursors": ${jsonencode(upstream_dns_servers)},
    "ca_file": "/opt/local/etc/consul.d/certificates/ca.pem",
    "cert_file": "/opt/local/etc/consul.d/certificates/cert.pem",
    "key_file": "/opt/local/etc/consul.d/certificates/private_key.pem",
    "verify_incoming": false,
    "verify_outgoing": false,
    "verify_server_hostname": true,
}