require 'faye/websocket'
require 'eventmachine'
require 'json'

class OpenSeaStream
  def initialize(api_key:, collections:, &on_event)
    @api_key     = api_key
    @collections = collections
    @on_event    = on_event
    @ref         = 0
  end

  def run
    EM.run do
      url = "wss://stream-api.opensea.io/socket/websocket?token=#{@api_key}"

      @ws = Faye::WebSocket::Client.new(url, nil, {
        headers: { 'Origin' => 'https://opensea.io' },
        ping:    10
      })

      @ws.on(:open)    { |_e| on_open }
      @ws.on(:message) { |e|  on_message(e.data) }
      @ws.on(:close)   { |e|  on_close(e) }
      @ws.on(:error)   { |e|  puts "WebSocket error: #{e.message}" }
    end
  end

  private

  def on_open
    puts "Connected to OpenSea stream"
    @heartbeat_timer&.cancel
    send_heartbeat
    EM.add_timer(1) do
      @collections.each { |slug| join_collection(slug) }
    end
    @heartbeat_timer = EM.add_periodic_timer(25) { send_heartbeat }
  end

  def on_message(raw)
    data = JSON.parse(raw)

    # Phoenix v2 sends arrays: [join_ref, ref, topic, event, payload]
    if data.is_a?(Array)
      event = data[3]
      payload_wrapper = data[4]
      return unless payload_wrapper.is_a?(Hash)

      event_type = payload_wrapper['event_type']
      return unless event_type

      puts "Event received: #{event_type}"
      @on_event.call(event_type, payload_wrapper['payload'])
      return
    end

    # Hash format (older Phoenix protocol, heartbeat replies)
    return unless data.is_a?(Hash)
    return if ['phx_reply', 'phx_error'].include?(data['event'])

    event_type = data.dig('payload', 'event_type')
    return unless event_type

    puts "Event received: #{event_type}"
    @on_event.call(event_type, data['payload'])
  rescue JSON::ParserError => e
    puts "JSON parse error: #{e.message}"
  end

  def on_close(event)
    puts "Connection closed (#{event.code}). Reason: #{event.reason}"
    if event.code == 1002 || event.code == 4001
      puts "Auth error — not reconnecting."
      EM.stop
    else
      puts "Reconnecting in 5s..."
      EM.add_timer(5) { run }
    end
  end

  def join_collection(slug)
    topic = slug == '*' ? 'collection:*' : "collection:#{slug}"
    send_message(topic: topic, event: 'phx_join', payload: {})
    puts "Subscribed to: #{topic}"
  end

  def send_heartbeat
    send_message(topic: 'phoenix', event: 'heartbeat', payload: {})
    puts "Heartbeat sent"
  end

  def send_message(topic:, event:, payload:)
    @ref += 1
    @ws.send(JSON.generate({ topic: topic, event: event, payload: payload, ref: @ref }))
  end
end
