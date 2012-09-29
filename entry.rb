require './database.rb'
require 'net/http'
require 'uri'
require 'sanitize'

class Entry

    attr_accessor :id
    attr_accessor :body
    attr_accessor :title
    attr_accessor :date
    attr_accessor :author

    def initialize(*args)
        if args.length == 1
            initializeFromID(args[0])
        end
    end
    
    def initializeFromID(id)
        db = Database.new
        entryData = db.getEntryData(id)
        self.id = id
        self.body = entryData["body"]
        self.title = entryData["title"]
        self.date = entryData["date"]
        self.author = entryData["author"]
    end

    def save()
        db = Database.new
        if self.id == nil
            id = db.addEntry(self)
            entryData = db.getEntryData(id)        
            self.id = id
            self.body = entryData["body"]
            self.title = entryData["title"]
            self.date = entryData["date"]
            self.author = entryData["author"]
        else
            # edit
            db.editEntry(self)
        end
    end

    def delete()
        puts "deleting entry"
        db = Database.new
        db.deleteEntry(self.id)
    end

    def sendTrackbacks(request)
        # get list of links
        links = self.body.scan(/<a[^>]*href="(.*)"[^>]*>/)
        if links.length == 0
            return
        end

        puts "found links"
        
        # check links for trackback-urls
        uris = []
        links.each do |link|
            puts link
            uris.push(URI.parse(link[0].strip))
        end

        trackbackLinks  = []
        uris.each do |uri|
            http = Net::HTTP.new(uri.host, uri.port)
            http_request = Net::HTTP::Get.new(uri.request_uri)

            response = http.request(http_request)
            headLink = response.body.scan(/<link.*rel="trackback".*href="([^"]+)"[^>]*>/)
            if headLink.length > 0
                trackbackLinks.push(headLink)
                puts "found headLink"
            else
                rdfLink = response.body.scan(/<rdf:Description[^>]*trackback:ping="([^"]*)"/)
                if rdfLink.length > 0
                    puts "found rdfLink"
                    trackbackLinks.push(rdfLink)
                end
            end
        end
        
        # if there are trackback-enabled links, gather data
        if trackbackLinks.length == 0
            return
        end

        puts "gathering data"

        data = {"title" => self.title,
                "url" => "http://#{request.host_with_port}/#{self.id}/#{self.title}}",
                "excerpt" => Sanitize.clean(self.body)[0..30].gsub(/\s\w+$/, '...'),
                "blog_name" => "blog testblog"}
                
        trackbackLinks.each do |link|
            puts "sending to #{link}"
            uri = URI.parse(link.to_s.strip)
            req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")
            req.set_form_data(data)

            http = Net::HTTP.new(uri.host, uri.port)
            http.open_timeout = 40
            http.read_timeout = 20
            response = http.request(req)
            puts response
        end
    end

end