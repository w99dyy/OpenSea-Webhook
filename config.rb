module Config
  OPENSEA_API_KEY = ENV['OPENSEA_API_KEY']
  DISCORD_WEBHOOK = ENV['DISCORD_WEBHOOK_URL']

  COLLECTIONS = ['mash-it']

  EXCLUDED_NFTS = [
    'Jay and pets'
  ].map(&:downcase)

  MAX_PRICE_ETH = nil

  STREAM_URL = "wss://stream-api.opensea.io/socket/websocket?token=#{OPENSEA_API_KEY}"
  HEARBEAT_INTERVAL = 30
end
