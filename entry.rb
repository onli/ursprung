require './database.rb'
require 'net/http'
require 'uri'
require 'sanitize'
require 'RedCloth'
require 'xmlrpc/client'

class Entry

    attr_accessor :id
    attr_accessor :body
    attr_accessor :title
    attr_accessor :date
    attr_accessor :author
    attr_accessor :moderate

    def initialize(*args)
        case args.length
        when 1
            initializeFromID(args[0])
        when 2
            # creating entry from params and save in database
            params = args[0]
            request = args[1]
            self.body = params[:body]
            self.title = params[:title]
            self.id = params[:id] if params[:id] != nil
            # NOTE: That way, only one-user-blogs are possible:
            self.author = Database.new.getAdmin
            self.save
            remainingLinks = self.sendTrackbacks(request)
            puts remainingLinks.to_s
            if remainingLinks.length >= 1
                self.sendPingbacks(request, remainingLinks)
            end
            Database.new.getFriends.each{|friend| friend.notify}
        end
    end
    
    def initializeFromID(id)
        puts "creating entry from id: #{id}"
        db = Database.new
        entryData = db.getEntryData(id)
        self.id = id
        self.body = entryData["body"]
        self.title = entryData["title"]
        self.date = entryData["date"]
        self.author = entryData["author"]
        self.moderate = entryData["moderate"]
    end

    def save()
        db = Database.new
        if self.id == nil
            id = db.addEntry(self)
            initializeFromID(id)   # to get data added by the database, like the date
        else
            db.editEntry(self)
            initializeFromID(self.id)
        end
    end

    def delete()
        puts "deleting entry"
        db = Database.new
        db.deleteEntry(self.id)
    end

    def sendTrackbacks(request)
    
        puts "sending trackback"
        
        uris = self.links()
        if uris.length == 0
            return uris
        end
        puts "found links"
        
        # check links for trackback-urls

        trackbackLinks  = []
        uris.each do |uri|
            http = Net::HTTP.new(uri.host, uri.port)
            http_request = Net::HTTP::Get.new(uri.request_uri)

            response = http.request(http_request)
            headLink = Nokogiri::HTML(response.body).css("link").map do |link|
                puts link
                if (href = link.attr("href")) && link.attr("rel") == "trackback" && href.match(/^https?:/)
                    href
                end
            end.compact
            
            if headLink.length > 0
                trackbackLinks.push(headLink[0])
                uris.delete(uri)
                puts "found headLink: #{headLink}"
            else
                puts uri
                rdfLink = response.body.scan(/<rdf:Description[^>]*trackback:ping="([^"]*)"[^>]*dc:identifier="#{Regexp.escape(uri.to_s)}"/)
                if rdfLink.length > 0
                    puts "found rdfLink: #{rdfLink}"
                    trackbackLinks.push(rdfLink[0])
                    uris.delete(uri)
                end
            end
        end
        
        # if there are trackback-enabled links, gather data
        if trackbackLinks.length == 0
            puts "no trackback-enabled links"
            return uris
        end

        puts "gathering data"

        data = {"title" => self.title,
                "url" => self.link(request),
                "excerpt" => Sanitize.clean(self.body)[0..30].gsub(/\s\w+$/, '...'),
                "blog_name" => Database.new.getOption("blogTitle")
                }
                
        trackbackLinks.each do |link|
            puts "sending to #{link}"
            uri = URI.parse(link.to_s.strip)
            req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")
            req.set_form_data(data)

            http = Net::HTTP.new(uri.host, uri.port)
            http.open_timeout = 40
            http.read_timeout = 20
            begin
                response = http.request(req)
                doc = Nokogiri::XML(response.body)
                error = doc.xpath("/response/error")
                if error == 0
                    uris.delete(uri)
                else
                    puts response.body
                end
            rescue Exception => error
                puts error
            end
        end
        return uris
    end

    def sendPingbacks(request, remainingLinks = nil)
        puts "sending pingbacks"
        
        uris = remainingLinks
        if uris == nil
            uris = self.links()
        end
            
        if uris.length == 0
            return false
        end
        puts "found links"

        # check for pingback-url
        pingbackLinks  = []
        uris.each do |uri|
            http = Net::HTTP.new(uri.host, uri.port)
            http_request = Net::HTTP::Get.new(uri.request_uri)

            response = http.request(http_request)
            headLink = Nokogiri::HTML(response.body).css("link").map do |link|
                if (href = link.attr("href")) && link.attr("rel") == "pingback" && href.match(/^https?:/)
                    href
                end
            end.compact
            
            if headLink.length > 0
                pingbackLinks.push({ :target => uri, :server => headLink[0] })
                puts "found headLink: #{headLink}"
            end
        end
        
        if pingbackLinks.length == 0
            return false
        end

        # send pingback via xmlrpc
        pingbackLinks.each do |link|
            server = XMLRPC::Client.new2(link[:server])
            begin
                result = server.call('pingback.ping', self.link(request), link[:target].to_s)
            rescue Exception => error
                puts error
            end
            puts result
        end
        
    end

    # get list of links 
    def links()
        links = Nokogiri::HTML(RedCloth.new(self.body).to_html).css("a").map do |link|
            if (href = link.attr("href")) && href.match(/^https?:/)
                href
            end
        end.compact
        uris = []
        links.each do |link|
            puts link
            uris.push(URI.parse(link))
        end
        return uris
    end

    def link(request)
        return "http://#{request.host_with_port}/#{self.id}/#{URI.escape(title)}"
    end

end