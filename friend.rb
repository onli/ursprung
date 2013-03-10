require 'net/http'
require 'uri'
require './dsnns.rb'

class Friend
    attr_accessor :name

    def initialize(*args)
        case args.length
        when  1
            self.name = args[0]
        end
    end

    # get URL for this id from dsnns
    def url()
        return Dsnns.new.url(self.name)
    end

    # This friend has written a new entry, update stream or mark for later
    def hasUpdate()
        uri = URI.parse(self.url + '/feed')
        http = Net::HTTP.new(uri.host, uri.port)
        http_request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(http_request)
        
        doc = Nokogiri::XML(response.body)
        doc.remove_namespaces! # removes the wrong part, content:encoded becomes encoded

        db = Database.new
        doc.xpath('/rss/channel/item').each do |item|
            db.fillStream(  item.css('content').text != "" ? item.css('content').text : item.css('encoded').text,
                            item.css('title').text,
                            self.name,
                            Time.parse(item.css('pubDate').text).to_i,
                            item.css('link').text,
                            item.css('guid').text
                        )
        end
    end

    
    # This friend has written a new message and we have the key, fetch the content
    def hasMessage(id, key)
        uri = URI.parse(self.url + "/message")
        uri.query = URI.encode_www_form( {:id => id } )
        
        http = Net::HTTP.new(uri.host, uri.port)
        http_request = Net::HTTP::Get.new(uri.request_uri)
        begin
            response = http.request(http_request)
        rescue => error
            puts "Error getting message"
        end
        content = response.body

        Message.new(content, key, self.name, Database.new.getAdminMail)
    end

    # notify friend-blog of new content on this blog
    # NOTE: Use only as fallback if dsnns is not reachable
    def notify()
        uri = URI.parse(self.url + '/entry')
        http = Net::HTTP.new(uri.host, uri.port)
        http_request = Net::HTTP::Post.new(uri.request_uri)
        http_request.set_form_data({:id => Database.new.getAdminMail})
        begin
            http.request(http_request)
        rescue => error
            puts "Error notifying #{self.name}: #{error}"
        end
    end

    # notify friend-blog of new message on this blog and send the key
    def send(message)
        uri = URI.parse(self.url + '/message')
        http = Net::HTTP.new(uri.host, uri.port)    # TODO: Use SSL
        http_request = Net::HTTP::Post.new(uri.request_uri)
        http_request.set_form_data({:id => Database.new.getAdminMail, :key => message.key, :mid => message.id})
        begin
            http.request(http_request)
        rescue => error
            puts "Error sending message to #{message.to}: #{error}"
        end
    end

    def save()
        Database.new.addFriend(self)
    end

    def subscribe()
        Dsnns.new.subscribe(self.name)
    end
    
end