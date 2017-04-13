#!/usr/bin/env ruby
require 'rubygems'

require_relative 'database.rb'
require_relative 'entry.rb'
require_relative 'comment.rb'

require 'sinatra/base'
require 'sanitize'
require 'htmlentities'
require 'xmlrpc/marshal'
require 'json'
include ERB::Util
require 'sinatra/browserid'
require 'sprockets'
require 'uglifier'
require 'cssminify'
require 'sinatra/url_for'
require 'thread/pool'
require 'rack/contrib/try_static'

module Ursprung
    class Ursprung < Sinatra::Application
        register Sinatra::BrowserID
        use Rack::Session::Pool

        set :static_cache_control, [:public, max_age: 31536000]

        set :assets, Sprockets::Environment.new

        class << self; attr_accessor :baseUrl end
        class << self; attr_accessor :pool end
        @pool = Thread.pool(2)

        helpers do
            include Rack::Utils
            alias_method :uh, :escape
            alias_method :h, :escape_html
            alias_method :u, :unescape

            def isAdmin?
                if authorized?
                    if Database.new.getAdminMail == authorized_email
                        return true
                    end
                end
                return false
            end

            def protected!
                unless isAdmin?
                    throw(:halt, [401, "Not authorized\n"])
                end
            end

            def blogOwner
                return Database.new.getAdmin
            end

            def blogOwnerMail
                return Database.new.getAdminMail
            end

            def blogTitle
                return Database.new.getOption("blogTitle")
            end

            def autotitle(text)
                db = Database.new
                Nokogiri::HTML(text).css("a").map do |link|
                    if (href = link.attr("href")) && link.attr("title") == nil && href.match(/^https?:/)
                        if ((title, _ = db.getCache(href)) == nil)
                            require 'mechanize'
                            agent = Mechanize.new
                            begin
                                title = agent.get(href).title
                            rescue Exception => error
                                title = ""
                            end
                            db.cache(href, title)
                        else
                            old_link = link
                            link = link.to_s.sub("<a", "<a title=\"#{title}\"")
                            begin
                                text[old_link.to_s] = link
                            rescue IndexError => ie
                                warn "could not insert #{title}"
                            end
                        end
                    end
                end
                return text
            end

            def excerpt (text, length = 200)
                if text.length >= length
                        splitFullString = text[0, length].split(/\s/)
                        splitFullString[0, splitFullString.length-1].join(" ") + '...'
                else
                        text
                end
            end

            def stripHtml(text)
                Sanitize.clean(text)
            end

            def htmlentities(text)
                return HTMLEntities.new.encode(text)
            end

            def find_template(views, name, engine, &block)
                super(views, name, engine, &block) if File.exists?(File.join(views, name.to_s + ".erb"))
                super(settings.design_default, name, engine, &block)
            end
        end

        def self.loadConfiguration()
            design = Database.new.getOption("design")
            settings.views = File.join(settings.design_root, design)
            use Rack::TryStatic, :root => File.join(settings.views, 'public'), :urls => %w[/]   # first look in the designs public folder
            settings.public_folder = 'public'   # and otherwise in the global one, where also all the uploads are
            settings.assets.clear_paths     # js/css files else stay the same after a design switch

            settings.assets.append_path File.join(settings.views, "js")
            settings.assets.append_path File.join(settings.views, "css")

            settings.assets.append_path File.join(settings.design_default, "js") if design != "default"
            settings.assets.append_path File.join(settings.design_default, "css") if design != "default"

            settings.assets.js_compressor  = Uglifier.new
            settings.assets.css_compressor = CSSminify.new
        end

        configure do
            set(:design_root) { File.join(File.dirname(__FILE__), "designs") }
            set(:design_default) { File.join(design_root, "default") }
            loadConfiguration
        end

        ####
        #
        # Careful: Don't let this become a blob. Delegate
        #
        ####

        before do
            Ursprung::baseUrl = url('/', :full)
        end

        get '/' do
            serveIndex()
        end

        get %r{/archive/([0-9]+)/([\w]+)} do |page, tag|
            serveIndex(page: page.to_i, tag: tag)
        end

        get %r{/archive/([0-9]+)} do |page|
            serveIndex(page: page.to_i)
        end
        
        get %r{/archive/([\w]+)} do |tag|
            serveIndex(page: -1, tag: tag)
        end

        def serveIndex(page: -1, tag: nil)
            db = Database.new
            if db.firstUse?
                db.setOption("secret", SecureRandom.urlsafe_base64(256))
                db.setOption("blogTitle", "just a blog")
                db.invalidateCache(nil)
                erb :installer
            else
                limit = 5
                totalPages, _ = db.getTotalPages(limit, tag)
                page = totalPages if page == -1
                entries = db.getEntries(page: page, limit: 5, tag: tag)
                designs = Dir.new(settings.design_root).entries.reject{|design| design == "." || design == ".." }
                design = db.getOption("design")
                    
                body erb :index, :locals => {:entries => entries, :page => page, :totalPages => totalPages, :designs => designs, :design => design, :tag => tag, :allTags => db.getAllTags}
            end
        end

        get %r{/feed/([\w]+)} do |tag|
            totalPages, _ = Database.new.getTotalPages(limit, tag)
            entries = Database.new.getEntries(page: -1, limit: 10, tag: tag)
            headers "Content-Type"   => "application/rss+xml"
            body erb :feed, :locals => {:entries => entries}
        end


        get '/feed' do
            entries = Database.new.getEntries(page: -1, limit: 10, tag: nil)
            headers "Content-Type"   => "application/rss+xml"
            body erb :feed, :locals => {:entries => entries}
        end

        post '/addEntry' do
            protected!
            entry = Entry.new(params, request)
            redirect url_for entry.link + '#new'
        end

        post %r{/([0-9]+)/addTrackback} do |id|
            paramsNew = {:name => params[:blog_name], :body => params[:excerpt], :entryId => id, :type => 'trackback', :url => params[:url], :mail => ""}
            trackback = Comment.new(paramsNew, request)
            if trackback.validTrackback
                '<?xml version="1.0" encoding="utf-8"?>
                <response>
                    <error>0</error>
                </response>'
            else
                '<?xml version="1.0" encoding="utf-8"?>
                <response>
                    <error>1</error>
                    <message>Could not find originating link</message>
                </response>'
            end
        end

        # solely used to handle pingbacks
        post '/xmlrpc' do
            xml = request.body.read
         
            if(xml.empty?)
                error = 400
                return
            end
         
            method, arguments = XMLRPC::Marshal.load_call(xml)

            if method == 'pingback.ping'
                source = arguments[0]
                target = arguments[1]
                id = target.gsub(/http:\/\/.*\/([0-9]*)\/.*/, '\1')

                paramsNew = {:name => "", :body => "", :entryId => id, :type => 'trackback', :url => source, :mail => ""}
                comment = Comment.new(paramsNew, request)
                content_type("text/xml", :charset => "utf-8")
                if comment.validTrackback
                    XMLRPC::Marshal.dump_response("Pingback successfully added")
                else
                    XMLRPC::Marshal.dump_response("Error: Didn't find pingback-link on originating page")
                    error = 400
                end
            else
                error = 404
            end
        end

        post '/file' do
            protected!
            filedata = Base64.decode64(params[:data].slice(params[:data].index('base64') + 7, params[:data].length))
            target = File.join(settings.public_folder, 'upload', params[:filename].gsub("..", ""))
            until ! File.exists?(target)
                return target.gsub(settings.public_folder, "") if Digest::MD5.hexdigest(filedata) == Digest::MD5.hexdigest(File.open(target).read())
                # assume the filename is a classical xy.abc, but dont forget the leading ./ of settings.public_folder
                target = target.reverse.sub('.','._').reverse if target.scan(".").size > 1
                target = target + "_" if target.scan(".").size <= 1
            end
            File.new(target, "w+").write(filedata)
            request.script_name + target.gsub(settings.public_folder, "").gsub(" ", "+")
        end

        get %r{/([0-9]+)/editEntry} do |id|
            protected!
            entry = Entry.new(id.to_i)
            erb :edit, :locals => {:entry => entry}
        end

        get %r{/([0-9]+)/editComment} do |id|
            protected!
            comment = Comment.new(id.to_i)
            entry = Entry.new(comment.replyToEntry)
            erb :editComment, :locals => {:comment => comment, :entry => entry}
        end

        post %r{/([0-9]+)/deleteComment} do |id|
            protected!
            Comment.new(id.to_i).delete
            "Done"
        end

        post %r{/([0-9]+)/spam} do |id|
            protected!
            comment = Comment.new(id.to_i)
            comment.spam()
            comment.delete
            "Done"
        end

        post %r{/([0-9]+)/ham} do |id|
            protected!
            comment = Comment.new(id.to_i)
            comment.ham()
            baseUrl = url_for '/', :full
            comment.save()   # ham also marks as approved, which needs to be saved
            return "Done" if ! request.xhr?
            erb :comment, :locals => {:comment => comment}
        end

        get %r{/([0-9]+)/verdict} do |id|
            if Comment.new(id.to_i).isSpam?
                "spam"
            else
                "ham"
            end
        end

        post %r{/([0-9]+)/deleteEntry} do |id|
            protected!
            Entry.new(id.to_i).deleteSoft
            "Done"
        end

        post %r{/([0-9]+)/restoreEntry} do |id|
            protected!
            Entry.new(id, nil, {:deleted => true}).save()
            "Done"
        end

        post %r{/([0-9]+)/addComment} do |id|
            entry = Entry.new(id.to_i)
            params[:entryId] = id

            comment = Comment.new(params, :new)
            
            redirect url_for (comment.entry.link + "#" + comment.status)
        end

        get '/commentFeed' do
            comments = Database.new.getComments(30)
            headers "Content-Type"   => "application/rss+xml"
            body erb :commentFeed, :locals => {:comments => comments}
        end

        post '/addAdmin' do
            db = Database.new
            if db.firstUse? && ! authorized_email.empty?
                name = params[:name]
                db.addUser(name, authorized_email)
                db.invalidateCache(nil)
                redirect to('/')
            else
                'Error adding admin: param missing or admin already set'
            end
        end

        post '/setOption' do
            protected!
            Database.new.setOption(params[:name], params[:value])
            Database.new.invalidateCache(nil)   # options are normally mighty enough to invalidate everything
            Ursprung::loadConfiguration
            origin = session[:origin]
            # when setOption wasn't called first, like with the design, origin is old, so unset it
            session.delete(:origin)
            redirect origin if origin != nil
            redirect back
        end

        get %r{/setOption/([\w]+)} do |name|
            protected!
            session[:origin] = back
            erb :editOption, :locals => {:name => name, :value => Database.new.getOption(name)}
        end

        get %r{/search/([\w]+)} do |keyword|
            db = Database.new
            designs = Dir.new(settings.design_root).entries.reject{|design| design == "." || design == ".." }
            design = db.getOption("design")
            body erb :search, :locals => {:entries => db.searchEntries(keyword), :keyword => keyword, :designs => designs, :design => design}
        end

        get '/search' do
            redirect url_for '/search/'+params[:keyword]
        end

        post '/preview' do
            protected!
            entry = Entry.new(params.merge({:preview => true}), request)
            entry.date = DateTime.now().to_s
            Database.new.deleteStoredEntries()    # this has nothing to do with the preview, it just need to be somewhere
            erb :entry, :locals => {:entry => entry}
        end

        post %r{/([0-9]+)/setEntryModeration} do |id|
            protected!
            Database.new.setEntryModeration(id, params[:value])
            redirect back if ! request.xhr?
        end

        # A Page (entry with comments)
        get  %r{/([0-9]+)/([\w]+)} do |id, title|
            db = Database.new
            entry = Entry.new(id.to_i)
            comments = db.getCommentsForEntry(id)
            designs = Dir.new(settings.design_root).entries.reject{|design| design == "." || design == ".." }
            design = db.getOption("design")
            body erb :page, :locals => {:entry => entry, :comments => comments, :designs => designs, :design => design}
        end

        get '/subscriptions/:mail' do
            db = Database.new
            cipher = OpenSSL::Cipher::Cipher.new('bf-cbc').send(:decrypt)
            cipher.key = Digest::SHA256.digest(db.getOption("secret"))
            mail = cipher.update(params[:mail]) << cipher.final
            body erb :subscriptions, :locals => {:mail => mail, :entries => db.getEntriesSubscribed(mail), :encryptedMail => params[:mail]}
        end

        post '/unsubscribe' do
            db = Database.new
            cipher = OpenSSL::Cipher::Cipher.new('bf-cbc').send(:decrypt)
            cipher.key = Digest::SHA256.digest(db.getOption("secret"))
            mail = cipher.update(u(params[:encryptedMail])) << cipher.final
            db.unsubscribe(mail, params[:id])
            db.invalidateCache("/subscriptions/%")
            redirect back
        end

        get %r{/designinfo/([\w]+)} do |availableDesign|
            target = File.join(settings.design_root, availableDesign.gsub("..", ""), 'about.txt')
            body File.new(target).read
        end


        get "/js/:file.js" do
          content_type "application/javascript"
          body settings.assets[params[:file]+".js"].to_s
        end

        get "/css/:file.css" do
          content_type "text/css"
          body settings.assets[params[:file]+".css"].to_s
        end

        post '/logout' do
            logout!
            redirect url_for '/'
        end
    end
end
