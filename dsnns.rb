require 'net/http'
require 'uri'

class Dsnns
    attr_accessor :friendManagerUrl

    def initialize()
        self.friendManagerUrl = "http://onli.no-ip.org:45678/" 
        puts "initialized dsnns being served by #{self.friendManagerUrl}"
    end 


    def url(id)
        uri = URI.parse(self.friendManagerUrl + 'url')
        http = Net::HTTP.new(uri.host, uri.port)
        http_request = Net::HTTP::Get.new(uri.request_uri)
        http_request.set_form_data({:id => id})
        begin
            response = http.request(http_request)
            body = JSON.parse(response.body)
            url = body['url']
            url = url + '/' if url[-1] != '/'
            if response.code == "200"
                return url if body['url'] != "not registered!"
            end
        rescue Errno::ECONNREFUSED => e
            puts "Couldn't connect to dsnns: #{e}"
        end
    end

    # let dsnns know that this blog has a new entry, so it can ping its subscribers.
    # This way also non-friends can be reached
    def notify
        uri = URI.parse(self.friendManagerUrl + 'notify')
        http = Net::HTTP.new(uri.host, uri.port)
        http_request = Net::HTTP::Get.new(uri.request_uri)
        http_request.set_form_data({:id => Database.new.getAdminMail})
        begin
            http.request(http_request)
            return true
        rescue Errno::ECONNREFUSED => e
            puts "Couldn't connect to dsnns: #{e}"
        end
        return false
    end
    
end