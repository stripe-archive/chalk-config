# Chalk::Config

A configuration layer over configatron.

To use, create a `config_schema.yaml` file in your repo base like the
following:

    files:
      # Which file to use to discover environment state. If
      # files_optional is set and the file doesn't exist, default
      # values will be used. (In practice we only create an env file
      # on servers.)  This should be a YAML file file of the form:
      #
      #   environment: qa|null|...
      #   personality: production|development
      #   deployed: true|false
      #   testing: true|false
      env_file: /etc/env.yaml

    # Which environment keys to set using environment variables. (This
    # interface is poorly supported at the moment; you can only set to
    # strings and not booleans.)
    env:
      testing: CHALK_TESTING

    # Where to load configuration from. Configuration under nested is
    # nested in configatron, so in this case we'd load configatron.foo
    # with the contents of foo/bar.yaml.
    config:
      file: config.yaml
      nested:
        foo: foo/bar.yaml

    # Where to load site-specific configuration from. That's a
    # convenient place to store secrets. You probably don't want to
    # store it in your version control.
    site:
      file: [/pay/conf/pay-server.yaml, site.yaml]

    # Don't explode if any of the files mentioned above are missing.
    files_optional: true

    # There are four environment keys which chalk-config tries to
    # infer:
    #
    #     environment: qa|null|... -- The class of machine the code is on
    #     personality: production|development -- Whether this is a dev machine or not
    #     deployed: true|false -- Whether this is on a local machine or a server
    #     testing: true|false -- Whether the tests are being run
    #
    # You can specify overrides as a function of these keys. So for example,
    # the following config sets configatron.foo to 1234 only for personality =
    # production.
    overrides:
      personality:
        production:
          foo: 1234

## Usage

First, set the root of your project via `Chalk::PathUtils.basedir =
directory`. You can then explicitly initialize chalk-config via
`Chalk::Config.init`.

Config then goes through all specified config files and merges them
into the global configatron object, mixing in any overrides as it
goes.
