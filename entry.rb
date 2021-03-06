require './database.rb'
require 'uri'
require 'xmlrpc/client'
require 'kramdown'
require 'http'
require 'strings'

module Ursprung
    class Entry
    
        attr_accessor :id
        attr_accessor :body
        attr_accessor :title
        attr_accessor :date
        attr_accessor :author
        attr_accessor :moderate   # 'open', 'moderated', 'closed' 
        attr_accessor :tags

        def initialize(*args)
            case args.length
            when 1
                initializeFromID(args[0], false)
            when 2
                # creating entry from params 
                params = args[0]
                self.body = params[:body]
                self.title = params[:title].strip
                self.id = params[:id] if params[:id] != nil
                self.tags = params[:tags].split(",").map!{ |tag| tag.strip }.uniq() if params[:tags] != nil
                # NOTE: That way, only one-user-blogs are possible:
                self.author = Database.new.getAdmin
                # and save in database, if not a preview
                if not params[:preview]
                    self.save
                    Ursprung::pool.process {
                        remainingLinks = self.sendTrackbacks()
                        if remainingLinks.length >= 1
                            self.sendPingbacks(remainingLinks)
                        end
                        self.pingHub
                    }
                end
            when 3
                # get the entry from the recycler
                initializeFromID(args[0], true)
            end
        end
        
        def initializeFromID(id, deleted)
            db = Database.new
            entryData = db.getEntryData(id, deleted)
            if entryData != nil
                self.id = id
                self.body = entryData["body"]
                self.title = entryData["title"]
                self.date = entryData["date"]
                self.author = entryData["author"]
                self.moderate = entryData["moderate"]
                self.tags = entryData["tags"]
            end
        end

        def save()
            db = Database.new
            if self.id == nil
                id = db.addEntry(self)
                initializeFromID(id, false)   # to get data added by the database, like the date
            else
                db.editEntry(self)
                initializeFromID(self.id, false)
            end
            db.invalidateCache(self)
        end

        def deleteSoft()
            db = Database.new
            db.deleteEntrySoft(self.id)
            db.invalidateCache(self)
        end

        def delete()
            db = Database.new
            db.deleteEntry(self.id)
        end

        def sendTrackbacks()
            uris = self.links()
            if uris.length == 0
                return uris
            end
            
            # check links for trackback-urls
            trackbackLinks  = []
            uris.each do |uri|
                response = uri.read
                headLink = Oga.parse_html(response).css("link").map do |link|
                    if (href = link.attr("href").value) && link.attr("rel").value == "trackback" && href.match(/^https?:/)
                        href
                    end
                end.compact
                
                if headLink.length > 0
                    trackbackLinks.push(headLink[0])
                    uris.delete(uri)
                else
                    rdfLink = response.scan(/<rdf:Description[^>]*trackback:ping="([^"]*)"[^>]*dc:identifier="#{Regexp.escape(uri.to_s)}"/)
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

            puts self.format

            puts 'generating trackback payload'
            data = {"title" => self.title,
                    "url" => Ursprung::baseUrl + self.link(),
                    "excerpt" => Strings.truncate(self.format.gsub(/<\/?[^>]*>/, ' ').gsub(/\n\n+/, '\n').gsub(/^\n|\n$/, ' ').strip.split.join(" "), 30),
                    "blog_name" => Database.new.getOption("blogTitle")
                    }
            p data
                    
            trackbackLinks.each do |link|
                begin
                    response = HTTP.post(link.to_s.strip, :form => data)
                    doc = Oga.parse_xml(response.to_s)
                    error = doc.xpath("/response/error")
                    uris.delete(uri) if error == 0
                rescue Exception => e
                    warn e
                end
            end
            return uris
        end

        def sendPingbacks(remainingLinks = nil)
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
                response = uri.read
                headLink = Oga.parse_html(response).css("link").map do |link|
                    if (href = link.attr("href").value) && link.attr("rel").value == "pingback" && href.match(/^https?:/)
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
                    result = server.call('pingback.ping', Ursprung::baseUrl + self.link(), link[:target].to_s)
                rescue Exception => error
                    warn error
                end
            end
            
        end
        
        def pingHub()
            HTTP.post("https://pubsubhubbub.superfeedr.com/", :form => {:'hub.mode' => "publish", :'hub.url' => "#{Ursprung::baseUrl}feed"})
        end

        # get list of links 
        def links()
            links = Oga.parse_html(self.format).css("a").map do |link|
                if (href = link.attr("href").value) && href.match(/^https?:/)
                    href
                end
            end.compact
            uris = []
            links.each do |link|
                begin
                    uris.push(URI.parse(URI.escape(link)))
                rescue URI::InvalidURIError => error
                    warn "could not parse link: " + error.to_s
                end
            end
            return uris
        end

        def link()
            begin
                return "/#{self.id}/#{URI.escape(title)}"
            rescue => error
                warn "could not create link: " + error.to_s
                return "/#{self.id}/404"
            end
        end

        # get the number of the archive this article is listed on
        def archivePage()
            limit = 5
            position = Database.new.getAllEntryIds().index({ "id" => self.id.to_f, 0 => self.id.to_f })
            return (position.to_f / limit).ceil
        end

        def format()
            # NOTE: :hard_wrap will only work in future versions
            begin
                return Kramdown::Document.new(self.body, :auto_ids => false, :hard_wrap => true).to_html
            rescue  => error
                warn "could not format entry: " + error.to_s
                return self.body
            end
        end
    end
end
