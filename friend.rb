require 'net/http'
require 'uri'

class Friend
    attr_accessor :name
    attr_accessor :url

    def initialize(*args)
        case args.length
        when  1
            friendData = Database.new.getFriendData(args[0])
            self.name = friendData["name"]
            self.url = friendData["url"]
        end
    end

    # get URL for this id from dsnns
    def getUrl()

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

    # notify friend-blog of new content on this blog
    def notify()
        uri = URI.parse(self.url + '/entry')
        http = Net::HTTP.new(uri.host, uri.port)
        http_request = Net::HTTP::Post.new(uri.request_uri)
        http_request.set_form_data({"id" => Database.new.getAdminMail})
        begin
            http.request(http_request)
        rescue => error
            puts "Error notifying #{self.name}: #{error}"
        end
    end

    
end