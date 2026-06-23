require 'dotenv/load'
require_relative 'config'
require_relative 'opensea_stream'
require_relative 'event_handler'

key = Config::OPENSEA_API_KEY
abort "No key!" if key.nil? || key.strip.empty?

handler = EventHandler.new(
  webhook_url:   Config::DISCORD_WEBHOOK,
  max_price_eth: Config::MAX_PRICE_ETH
)

stream = OpenSeaStream.new(
  api_key:     Config::OPENSEA_API_KEY,
  collections: Config::COLLECTIONS
) do |event_type, payload|
  handler.handle(event_type, payload)
end

puts "Starting OpenSea stream webhook..."
stream.run  # blocks forever (EventMachine loop)
