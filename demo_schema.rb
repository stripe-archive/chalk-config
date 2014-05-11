Chalk::Config.environment = 'local'

Chalk::Config.register('config.yaml')
Chalk::Config.register('secrets.yaml')

Chalk::Config.register('ops/ops-secrets.yaml', nested: 'ops')

Chalk::Config.environment = 'production'
