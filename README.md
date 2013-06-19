# Chalk::Config

A configuration layer over configatron.

To use, create a `config_schema.yaml` file in your repo base like the
following:

    # environment: qa|nil|ci
    # personality: production|development
    # deployed: true|false
    # testing: true|false
    files:
      env_file: /pay/conf/env.yaml
    
    env:
      testing: STRIPE_TESTING
    
    config:
      file: config.yaml
      nested:
        ops: ops/ops.yaml
    
    site:
      file: [/pay/conf/pay-server.yaml, site.yaml]
      nested:
        ops: ops/ops-site.yaml
    
    files_optional: true
