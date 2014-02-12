# Chalk::Config

A configuration layer over configatron.

## Usage

### Registering config files

It's easy to create YAML configuration files:

    # /top/secret/site.yaml

    password: hunter2

    database:
      secret: 53CR37

    logs: /secret/location

    # cookies.yaml

    ingredients: 'A lot of sugar and butter'
    instructions: 'Mix and bake'


The properties specified will then be added to the global
configatron object when you register the file:

    > Chalk::Config.register('/top/secret/site.yaml')
    > configatron.password
    => "hunter2"

Nested properties also work as expected:

    > configatron.database.secret
    => "53CR37"

You can also explicitly nest a config file:

    > Chalk::Config.register('cookies.yaml', nested: 'cookies')

    > configatron.cookies.ingredients
    => "A lot of sugar and butter"

    > configatron.ingredients
    =>


### Setting overrides for different environments

You can set overrides for configured properties based on environment name:

    # years.yaml

    year: 1984

    overrides:
      production:
        year: 2014

      apocalyptic:
        year: 2050

If you then set `Chalk::Config.environment`, Config will override
the default `'year'` property on the global configatron object:

    > Chalk::Config.register('years.yaml')

    > configatron.year
    => 1984

    > Chalk::Config.environment = 'production'
    > configatron.year
    => 2014

    > Chalk::Config.environment = 'apocalyptic'
    > configatron.year
    => 2050

    > Chalk::Config.environment = 'aquatic'
    > configatron.year
    => 1984

