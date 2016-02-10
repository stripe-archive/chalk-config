class Chalk::Config
  # Base error class for Chalk::Config
  class Error < StandardError; end
  # Thrown if an environment is missing from a config file.
  class MissingEnvironment < Error; end
  # Thrown from environment assertions.
  class DisallowedEnvironment < Error; end
  # Thrown if a YAML file parses empty (mixture of empty lines and comments)
  class EmptyYamlFileError < Error; end
end
