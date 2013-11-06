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
    attr_accessor :tags

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
            self.tags = params[:tags].split(",") if params[:tags] != nil
            # NOTE: That way, only one-user-blogs are possible:
            self.author = Database.new.getAdmin
            self.save
            remainingLinks = self.sendTrackbacks(request)
            if remainingLinks.length >= 1
                self.sendPingbacks(request, remainingLinks)
            end
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
        self.moderate = entryData["moderate"]
        self.tags = entryData["tags"]
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
        db = Database.new
        db.deleteEntry(self.id)
    end

    def sendTrackbacks(request)
        uris = self.links()
        if uris.length == 0
            return uris
        end
        
        # check links for trackback-urls
        trackbackLinks  = []
        uris.each do |uri|
            http = Net::HTTP.new(uri.host, uri.port)
            http_request = Net::HTTP::Get.new(uri.request_uri)

            response = http.request(http_request)
            headLink = Nokogiri::HTML(response.body).css("link").map do |link|
                if (href = link.attr("href")) && link.attr("rel") == "trackback" && href.match(/^https?:/)
                    href
                end
            end.compact
            
            if headLink.length > 0
                trackbackLinks.push(headLink[0])
                uris.delete(uri)
            else
                rdfLink = response.body.scan(/<rdf:Description[^>]*trackback:ping="([^"]*)"[^>]*dc:identifier="#{Regexp.escape(uri.to_s)}"/)
                if rdfLink.length > 0
                    trackbackLinks.push(rdfLink[0])
                    uris.delete(uri)
                end
            end
        end
        
        # if there are trackback-enabled links, gather data
        if trackbackLinks.length == 0
            return uris
        end

        data = {"title" => self.title,
                "url" => self.link(request),
                "excerpt" => Sanitize.clean(self.body)[0..30].gsub(/\s\w+$/, '...'),
                "blog_name" => Database.new.getOption("blogTitle")
                }
                
        trackbackLinks.each do |link|
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
                uris.delete(uri)  if error == 0
            rescue Exception => error
                puts error
            end
        end
        return uris
    end

    def sendPingbacks(request, remainingLinks = nil)
        uris = remainingLinks
        if uris == nil
            uris = self.links()
        end
            
        if uris.length == 0
            return false
        end

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
            uris.push(URI.parse(link))
        end
        return uris
    end

    def link(request)
        return "http://#{request.host_with_port}/#{self.id}/#{URI.escape(title)}"
    end

    def format()
        formattedBody = self.body
        formattedBody = formattedBody.gsub(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
        formattedBody = formattedBody.gsub(/\*(.*?)\*/, '<em>\1</em>')
        # images
        formattedBody = formattedBody.gsub(/\[\[([^ ]*?)\]\]/, '<img src="\1" \/>')
        # link without name:
        formattedBody = formattedBody.gsub(/\[([^ ]*?)\]/, '<a href="\1">\1</a>')
        # link with title: [url "title" name]
        formattedBody = formattedBody.gsub(/\[([^ ]*?) "(.*?)" (.*?)\]/, '<a href="\1" title="\2">\3</a>')
        # link: [url name]
        formattedBody = formattedBody.gsub(/\[(.*?) (.*?)\]/, '<a href="\1">\2</a>')
        return formattedBody
    end

end