require 'socket'
require 'uri'
Gem.configuration
src = Gem.sources.first
begin
  Socket.gethostbyname(URI.parse(src).host)
rescue SocketError => e
  STDERR.puts "Unable to resolve gem source #{s}"
end
source src

# Specify your gem's dependencies in chalk-config.gemspec
gemspec
