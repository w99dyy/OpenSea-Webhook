require 'bigdecimal'
require 'discordrb/webhooks'

class EventHandler
  def initialize(webhook_url:, max_price_eth: nil)
    @webhook    = Discordrb::Webhooks::Client.new(url: webhook_url)
    @max_price  = max_price_eth
  end

  def handle(event_type, payload)
    case event_type
    when 'item_listed'   then handle_listing(payload)
    when 'item_sold'     then handle_sale(payload)
  #  when 'item_cancelled' then handle_cancel(payload)
    end
  end

  private

  # Listings
    def handle_listing(payload)
    price_eth = wei_to_eth(payload['base_price'])
    return if @max_price && price_eth > @max_price  # filter by price

    item      = payload['item']
    name      = item.dig('metadata', 'name') || 'Unknown NFT'
    image     = item.dig('metadata', 'image_url')
    link      = item['permalink']
    collection = payload.dig('collection', 'slug')
    maker     = payload.dig('maker', 'address')
    symbol    = payload.dig('payment_token', 'symbol') || 'ETH'

    return if Config::EXCLUDED_NFTS.any? { |excluded| name.downcase.include?(excluded) }
    
    post_embed(
      content: "**New Listing!**",
      color:  0x2081E2,
      title:  "#{name}",
      url:    link,
      image:  image,
      fields: [
        { name: 'Price',      value: "#{format_price(price_eth)} #{symbol}", inline: true },
        { name: 'Collection', value: collection,                             inline: true },
        { name: 'Seller',     value: short_address(maker),                  inline: true }
      ]
    )
  end

  # Sales
  def handle_sale(payload)
    price_eth = wei_to_eth(payload['sale_price'])
    item      = payload['item']
    name      = item.dig('metadata', 'name') || 'Unknown NFT'
    image     = item.dig('metadata', 'image_url')
    link      = item['permalink']
    collection = payload.dig('collection', 'slug')
    buyer     = payload.dig('taker', 'address')
    symbol    = payload.dig('payment_token', 'symbol') || 'ETH'

    post_embed(
      content: "**Mashi Sold!**",
      color:  0x00C853,
      title:  "#{name}",
      url:    link,
      image:  image,
      fields: [
        { name: 'Sale Price', value: "#{format_price(price_eth)} #{symbol}", inline: true },
        { name: 'Collection', value: collection,                             inline: true },
        { name: 'Buyer',      value: short_address(buyer),                  inline: true }
      ]
    )
  end

  # Cancellations
#  def handle_cancel(payload)
#    item  = payload['item']
#    name  = item.dig('metadata', 'name') || 'Unknown NFT'
#    image = item.dig('metadata', 'image_url')
#    link  = item['permalink']
#
#    post_embed(
#      color:  0xFF5252,  # red for cancels
#      title:  "Listing Cancelled: #{name}",
#      url:    link,
#      image: image,
#      fields: [
#        { name: 'Collection', value: payload.dig('collection', 'slug'), inline: true }
#      ]
#    )
#  end

  # Helpers

  # Convert Wei (integer string) to ETH (float)
  # Uses BigDecimal to avoid floating point errors on large numbers
  def wei_to_eth(wei_str)
    return 0.0 unless wei_str
    (BigDecimal(wei_str) / BigDecimal('1000000000000000000')).to_f
  end

  def eth_to_usd(eth_amount)
    @eth_price_cache ||= { price: nil, fetched_at: nil }

    # Refresh price every 5 minutes
    if @eth_price_cache[:fetched_at].nil? || Time.now - @eth_price_cache[:fetched_at] > 300
      uri = URI('https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd')
      res = Net::HTTP.get(uri)
      @eth_price_cache[:price]      = JSON.parse(res).dig('ethereum', 'usd')
      @eth_price_cache[:fetched_at] = Time.now
      puts "ETH price refreshed: $#{@eth_price_cache[:price]}"
    end

    return nil unless @eth_price_cache[:price]
    eth_amount * @eth_price_cache[:price]
  rescue => e
    puts "Price fetch error: #{e.message}"
    nil
  end

  def format_price(eth, symbol = 'ETH')
    usd = eth_to_usd(eth)
    usd_str = usd ? " (~$#{format('%.0f', usd)})" : ""
    eth_str = eth < 0.001 ? '< 0.001' : format('%.4f', eth)
    "#{eth_str} #{symbol}#{usd_str}"
  end

  def short_address(addr)
    return 'unknown' unless addr
    "#{addr[0..5]}...#{addr[-4..]}"
  end

  def post_embed(color:, title:, url: nil, image: nil, fields: [], content: nil)
    @webhook.execute do |builder|
      builder.content = content if content
      builder.add_embed do |e|
        e.color       = color
        e.title       = title
        e.url         = url
        e.image       = Discordrb::Webhooks::EmbedImage.new(url: image) if image
        e.timestamp   = Time.now
        fields.each do |f|
          e.add_field(name: f[:name], value: f[:value].to_s, inline: f[:inline])
        end
      end
    end
  rescue => err
    puts "Discord webhook error: #{err.message}"
  end
end
