#!/usr/bin/env ruby
require 'rubygems'

require './database.rb'
require './entry.rb'
require './comment.rb'
require './commentauthor.rb'

require 'sinatra'
require 'sanitize'
require 'htmlentities'
require 'xmlrpc/marshal'
require 'json'
include ERB::Util
require 'sinatra/browserid'
require 'sprockets'
require 'yui/compressor'


enable :sessions
set :browserid_login_button, "/img/browserid.png"

set :static_cache_control, [:public, max_age: 31536000]

set :assets, Sprockets::Environment.new

helpers do
    include Rack::Utils
    alias_method :h, :escape
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
                    text = text.sub(old_link, link);
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

def loadConfiguration()
    design = Database.new.getOption("design")
    settings.views = File.join(settings.design_root, design)
    settings.public_folder = File.join(settings.views, 'public')

    settings.assets.clear_paths     # js/css files else stay the same after a design switch

    settings.assets.append_path File.join(settings.views, "js")
    settings.assets.append_path File.join(settings.views, "css")

    settings.assets.append_path File.join(settings.design_default, "js") if design != "default"
    settings.assets.append_path File.join(settings.design_default, "css") if design != "default"

    settings.assets.js_compressor  = YUI::JavaScriptCompressor.new
    settings.assets.css_compressor = YUI::CssCompressor.new

end

configure do
    set(:design_root) { File.join(File.dirname(app_file), "designs") }
    set(:design_default) { File.join(design_root, "default") }
    loadConfiguration()
end

####
#
# Careful: Don't let this become a blob. Delegate
#
####

before do
    @cacheContent = nil
    if request.request_method == "GET"
        @cacheContent, cacheCreation = Database.new.getCache("#{request.path_info}||==||#{authorized_email}")
        if @cacheContent != nil
            last_modified cacheCreation
            etag Digest::MD5.hexdigest(@cacheContent)
            content_type "text/css" if request.path_info[0,5] == "/css/"
            content_type "application/javascript" if request.path_info[0,4] == "/js/"
            halt @cacheContent
        end
    end
end

after do
    if @cacheContent == nil && request.request_method == "GET"
        Database.new.cache("#{request.path_info}#{authorized_email}", body)
        last_modified Date.to_s
        etag Digest::MD5.hexdigest(body.to_s)
    end
end

get '/' do
    serveIndex(-1, nil)
end

get %r{/archive/([0-9]+)/([\w]+)} do |page, tag|
    serveIndex(page.to_i, tag)
end

get %r{/archive/([0-9]+)} do |page|
    serveIndex(page.to_i, nil)
end

def serveIndex(page, tag)
    db = Database.new
    if db.firstUse?
        erb :installer
    else
        amount = 5
        entries = db.getEntries(page, amount, tag)
        totalPages, _ = db.getTotalPages(amount, tag)
        page = totalPages if page == -1
        friends = db.getFriends
        designs = Dir.new(settings.design_root).entries.reject{|design| design == "." || design == ".." }
        design = db.getOption("design")
            
        body erb :index, :locals => {:entries => entries, :page => page, :totalPages => totalPages, :friends => friends,
                                :designs => designs, :design => design, :tag => tag, :allTags => db.getAllTags}
    end
end

get %r{/feed/([\w]+)} do |tag|
    entries = Database.new.getEntries(-1, 10, tag)
    headers "Content-Type"   => "application/rss+xml"
    body erb :feed, :locals => {:entries => entries}
end


get '/feed' do
    entries = Database.new.getEntries(-1, 10, nil)
    headers "Content-Type"   => "application/rss+xml"
    body erb :feed, :locals => {:entries => entries}
end

post '/addEntry' do
    protected!
    entry = Entry.new(params, request)
    redirect "/#{entry.id}/#{URI.escape(entry.title)}"
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
    target.gsub(settings.public_folder, "").gsub(" ", "+")
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
    comment.spam
    comment.delete
    "Done"
end

post %r{/([0-9]+)/ham} do |id|
    protected!
    Comment.new(id.to_i).ham
    "Done"
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
    Comment.new(params, request)
    
    redirect "/#{entry.id}/#{entry.title}"
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
        redirect to('/')
    else
        'Error adding admin: param missing or admin already set'
    end
end

post '/setOption' do
    protected!
    Database.new.setOption(params[:name], params[:value])
    Database.new.invalidateCache
    loadConfiguration
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
    body erb :search, :locals => {:entries => Database.new.searchEntries(keyword), :keyword => keyword}
end

get '/search' do
    redirect '/search/'+params[:keyword]
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
    entry = Entry.new(id.to_i)
    comments = Database.new.getCommentsForEntry(id)
    body erb :page, :locals => {:entry => entry, :comments => comments}
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
    redirect '/'
end
