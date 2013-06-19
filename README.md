# Chalk::Config

Maps on-disk config files into a loaded global
[configatron](https://github.com/markbates/configatron) instance,
taking into account your current environment.

`configatron` is used within many Chalk gems to control their
behavior, and is also great for configuration within your application.

## Usage

### Environment

`Chalk::Config` relies on describing your environment as an opaque
string (`production`, `qa`, etc). You can set it like so:

```ruby
Chalk::Config.environment = 'production'
```

At that point, the global `configatron` will be cleared and all
registered config reapplied, meaning you don't have to worry about
setting the environment prior to registering files.

`environment` defaults to the value `'default'`.

### Registering config files

Additional configuration files are registered using
{Chalk::Config.register}. The most basic usage looks like

```ruby
Chalk::Config.register('/path/to/file')
```

to register a YAML configuration file. You must provide an absolute
path, in order to ensure you're not relying on the present working
directory. The following is a pretty good idiom:

```ruby
Chalk::Config.register(File.expand_path('../config.yaml', __FILE__))
```

By default, YAML configuration files should have a top-level key for
each environment.

A good convention is to have most configuration in a dummy `default`
environment and use YAML's native merging to keep your file somewhat
DRY (WARNING: there exists at least one gem which changes Ruby's YAML
parser in the presence of multiple merge operators on a single key, so
be wary of two `<<` calls at once.) However, it's also fine to repeat
yourself to make the file more human readable.

```yaml
# /path/to/config.yaml

default: &default
  my_feature:
    enable: true
    shards: 2

  my_service:
    host: localhost
    port: 2800

production:
  <<: *default
  my_service:
    host: appserver1
	port: 2800

  send_emails: true

development:
  <<: *default
  send_emails: false
```

The configuration from the currently active environment will then be
added to the global `configatron` when you register the file:

```ruby
Chalk::Config.register('/path/to/config.yaml')

Chalk::Config.environment = 'production'
configatron.my_service.host
#=> 'appserver1'

Chalk::Config.environment = 'development'
configatron.my_service.host
#=> 'localhost'
```

Keys present in multiple files will be deep merged:

```yaml
# /path/to/site.yaml

production:
  my_service:
    host: otherappserver

development: {}
```

```ruby
Chalk::Config.register('/path/to/config.yaml')
Chalk::Config.register('/path/to/site.yaml')

Chalk::Config.environment = 'production'
configatron.my_service.host
#=> 'otherappserver'
configatron.my_service.port
#=> 2800
```

You can explicitly nest a config file (only a single level of nesting
is current supported) using the `:nested` option. You can also
indicate a file has no environment keys and should be applied directly
via `:raw`:


```yaml
# /path/to/cookies.yaml

tasty: yes
```

```ruby
Chalk::Config.register('/path/to/cookies.yaml', nested: 'cookies', raw: true)
configatron.cookies.tasty
#=> 'yes'
```

## Best practices

### Config keys for everything

Writing code that switches off the environment is usually indicative
of the antipattern:

```ruby
# BAD!
if Chalk::Config.environment == 'production'
  email.send!
else
  puts email
end
```

Instead, you should create a fresh config key for all of these cases:

```ruby
if configatron.send_emails
  email.send!
else
  puts email
end
```

This means your code doesn't need to know anything about the set of
environment names, making adding a new environment easy. As well, it's
much easier to have fine-grained control and visibility over exactly
how your application behaves.

It's totally fine (and expected) to have many config keys that are
used only once.

# Contributors

- Greg Brockman
- Evan Broder
- Michelle Bu
- Nelson Elhage
- Jeremy Hoon
