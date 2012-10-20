#!/usr/bin/env ruby1.9.3
require 'rubygems'

require './database.rb'
require './entry.rb'
require './comment.rb'
require './commentauthor.rb'
require './friend.rb'

require 'sinatra'
require 'RedCloth'
require 'sanitize'
include ERB::Util
require 'sinatra/browserid'
set :sessions, true

helpers do
    include Rack::Utils
    alias_method :h, :escape

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

    def blogTitle
        return Database.new.getOption("blogTitle")
    end

    def autotitle(text)
        db = Database.new
        Nokogiri::HTML(text).css("a").map do |link|
            if (href = link.attr("href")) && link.attr("title") == nil && href.match(/^https?:/)
                if ((title = db.getCache(href)) == nil)
                    require 'mechanize'
                    agent = Mechanize.new
                    title = agent.get(href).title
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
                excFullString = text[0, length]
                splitFullString = excFullString.split(/\s/)
                fullWords = splitFullString.length
                splitFullString[0, fullWords-1].join(" ") + '...'
        else
                text
        end
    end

    def stripHtml(text)
        Sanitize.clean(text)
    end 

    def friendManagerUrl
        return "http://localhost:4200/"
    end
end

def loadConfiguration()
    design = Database.new.getOption("design")
    set(:design_root) { File.join(File.dirname(app_file), "designs") }
    set(:views) { File.join(design_root, design) }
    set(:public_folder) { File.join(views, 'public') }
end

configure do
   loadConfiguration
end

####
#
# Careful: Don't let this become a blob. Delegate
#
####

get '/' do
    serveIndex(-1)
end

get %r{/archive/([0-9]+)} do |page|
    serveIndex(page.to_i)
end

def serveIndex(page)
    db = Database.new
    if db.firstUse?
        erb :installer
    else
        entries = db.getEntries(page, 5)
        totalPages = db.getTotalPages
        page = totalPages if page == -1
        friends = db.getFriends
        designs = Dir.new(settings.design_root).entries.reject{|design| design == "." || design == ".." }
        design = db.getOption("design")
        return erb :index, :locals => {:entries => entries, :page => page, :totalPages => totalPages, :friends => friends,
                                :designs => designs, :design => design}
    end
end

post '/addEntry' do
    protected!
    entry = Entry.new()
    entry.body = params[:body]
    entry.title = params[:title]
    entry.id = params[:id] if params[:id] != nil
    # NOTE: That way, only one-user-blogs are possible:
    entry.author = blogOwner
    entry.save
    entry.sendTrackbacks(request)
    redirect "/#{entry.id}/#{entry.title}"
end

post %r{/([0-9]+)/addTrackback} do |id|
    commentAuthor = CommentAuthor.new
    commentAuthor.name = params[:blog_name]
    commentAuthor.url = params[:url]

    comment = Comment.new()
    comment.body = params[:excerpt]
    comment.title = params[:title]
    comment.replyToComment = nil
    comment.replyToEntry = id
    comment.author = commentAuthor
    comment.type = "trackback"
    comment.save
    
    '<?xml version="1.0" encoding="utf-8"?>
    <response>
       <error>0</error>
    </response>'
end

get %r{/([0-9]+)/editEntry} do |id|
    protected!
    entry = Entry.new(id)
    erb :edit, :locals => {:entry => entry}
end

get %r{/([0-9]+)/editComment} do |id|
    protected!
    comment = Comment.new(id)
    puts comment.replyToEntry
    entry = Entry.new(comment.replyToEntry)
    erb :editComment, :locals => {:comment => comment, :entry => entry}
end

post %r{/([0-9]+)/deleteComment} do |id|
    protected!
    Comment.new(id).delete
    "Done"
end

post %r{/([0-9]+)/spam} do |id|
    protected!
    comment = Comment.new(id)
    comment.spam
    comment.delete
    "Done"
end

post %r{/([0-9]+)/ham} do |id|
    protected!
    Comment.new(id).ham
    "Done"
end

get %r{/([0-9]+)/verdict} do |id|
    if Comment.new(id).isSpam?
        "spam"
    else
        "ham"
    end
end

post %r{/([0-9]+)/deleteEntry} do |id|
    protected!
    Entry.new(id).delete
    "Done"
end

post %r{/([0-9]+)/addComment} do |id|
    entry = Entry.new(id)
    commentAuthor = CommentAuthor.new
    commentAuthor.name = params[:name]
    commentAuthor.mail = params[:mail]
    commentAuthor.url = params[:url]

    comment = Comment.new()
    comment.replyToComment = params[:replyToComment].empty? ? nil : params[:replyToComment]
    comment.replyToEntry = id
    comment.body = params[:body]
    comment.author = commentAuthor
    comment.id = params[:id] if params[:id] != nil
    comment.status = "moderate" if comment.isSpam? or entry.moderate
    comment.subscribe = 1 if params[:subscribe] != nil
    comment.save
    
    redirect "/#{entry.id}/#{entry.title}"
end

# A Page (entry with comments)
get  %r{/([0-9]+)/([\w]+)} do |id, title|
    entry = Entry.new(id)
    comments = Database.new.getCommentsForEntry(id)
    erb :page, :locals => {:entry => entry, :comments => comments}
end

get '/feed' do
    entries = Database.new.getEntries(-1, 10)
    headers "Content-Type"   => "application/rss+xml"
    erb :feed, :locals => {:entries => entries}
end

get '/commentFeed' do
    comments = Database.new.getComments(30)
    headers "Content-Type"   => "application/rss+xml"
    erb :commentFeed, :locals => {:comments => comments}
end

post %r{/people/([\w]+)/([\w]+)} do |userid, groupid|
    protected!
    puts userid
    puts params[:url]
    Database.new.addFriend(userid, params[:url])
    redirect to('/')
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
    loadConfiguration
    origin = session[:origin]
    # when setOption wasn't called first, like with the design, origin is old, so unset it
    session.delete(:origin)
    redirect origin if origin != nil
    redirect back
end

get %r{/setOption/([\w]+)} do |name|
    protected!
    puts "setting option"
    session[:origin] = back
    erb :editOption, :locals => {:name => name, :value => Database.new.getOption(name)}
end

get %r{/search} do
    erb :search, :locals => {:entries => Database.new.searchEntries(params[:keyword]), :keyword => params[:keyword]}
end

post '/preview' do
    entry = Entry.new()
    entry.body = params[:body]
    entry.title = params[:title]
    entry.date = DateTime.now().to_s
    erb :entry, :locals => {:entry => entry}
end

get '/logout' do
    protected!
    logout!
    redirect '/'
end