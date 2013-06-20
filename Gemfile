require 'socket'
require 'uri'
Gem.configuration
if chalk_sources = ENV['CHALK_SOURCES']
  sources = chalk_sources.split(',')
else
  sources = Gem.sources
end
sources.each do |src|
  begin
    Socket.gethostbyname(URI.parse(src).host)
  rescue SocketError => e
    Bundler.ui.error("Unable to resolve gem source #{src}")
    raise e
  else
    source src
  end
end

gemspec
