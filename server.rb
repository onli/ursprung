#!/usr/bin/env ruby1.8
require 'rubygems'

require './database.rb'
require './entry.rb'
require './comment.rb'
require './commentauthor.rb'
require './friend.rb'

require 'sinatra'
require 'RedCloth'
include ERB::Util
require 'sinatra/browserid'
set :sessions, true

helpers do
    include Rack::Utils
    alias_method :h, :escape

    def isAdmin?
        if authorized?
            db = Database.new
            mails = db.getMails
            mails.each do |row|
                if row["mail"] == authorized_email
                    return true
                end
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
        db = Database.new
        return db.getAdmin
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

    def friendManagerUrl
        return "http://localhost:4200/"
    end
end

####
#
# Careful: Don't let this become a blob. Delegate
#
####

get '/' do
    db = Database.new
    if db.firstUse?
        erb :installer
    else
        entries = db.getEntries(-1, 5)
        totalPages = db.getTotalPages
        friends = db.getFriends
        blogTitle = db.getOption("blogTitle")
        erb :index, :locals => {:entries => entries, :page => totalPages, :totalPages => totalPages, :friends => friends, :blogTitle => blogTitle}
    end
end

get %r{/archive/([0-9]+)} do |page|
    db = Database.new
    entries = db.getEntries(page.to_i, 5)
    totalPages = db.getTotalPages
    friends = db.getFriends
    blogTitle = db.getOption("blogTitle")
    erb :index, :locals => {:entries => entries, :page => page, :totalPages => totalPages, :friends => friends, :blogTitle => blogTitle}
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
    Comment.new(id).spam
    Comment.delete
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
    puts comment.status
    comment.save
    
    redirect "/#{entry.id}/#{entry.title}"
end

# A Page (entry with comments)
get  %r{/([0-9]+)/([\w]+)} do |id, title|
    entry = Entry.new(id)
    db = Database.new
    comments = db.getCommentsForEntry(id)
    blogTitle = db.getOption("blogTitle")
    erb :page, :locals => {:entry => entry, :comments => comments, :blogTitle => blogTitle}
end

get '/feed' do
    db = Database.new
    entries = db.getEntries(-1, 5)
    headers "Content-Type"   => "application/rss+xml"
    erb :feed, :locals => {:entries => entries}
end

post %r{/people/([\w]+)/([\w]+)} do |userid, groupid|
    protected!
    puts userid
    puts params[:url]
    db = Database.new
    db.addFriend(userid, params[:url])
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
    db = Database.new
    db.setOption(params[:name], params[:value])
    redirect session[:origin]
end

get %r{/setOption/([\w]+)} do |name|
    protected!
    session[:origin] = back
    erb :editOption, :locals => {:name => name}
end

get '/logout' do
    protected!
    logout!
    redirect '/'
end

