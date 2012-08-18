#!/usr/bin/env ruby1.8
require 'rubygems'

require './database.rb'
require './entry.rb'
require './comment.rb'
require './commentauthor.rb'
require './friend.rb'

require 'sinatra'
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

    def friendManagerUrl
        return "http://localhost:4200/"
    end
end

get '/' do
    db = Database.new
    if db.firstUse?
        erb :installer
    else
        entries = db.getEntries(-1, 5)
        totalPages = db.getTotalPages
        friends = db.getFriends
        erb :index, :locals => {:entries => entries, :page => totalPages, :totalPages => totalPages, :friends => friends}
    end
end

get %r{/archive/([0-9]+)} do |page|
    db = Database.new
    entries = db.getEntries(page.to_i, 5)
    totalPages = db.getTotalPages
    erb :index, :locals => {:entries => entries, :page => page, :totalPages => totalPages}
end

post '/addEntry' do
    protected!
    entry = Entry.new()
    entry.body = params[:body]
    entry.title = params[:title]
    entry.author = "onli"
    db = Database.new
    id = db.addEntry(entry)

    entry = Entry.new(id)
    entry.sendTrackbacks(request)
    "Done"
end

post %r{/([0-9]+)/addTrackback} do |id|
    puts "adding trackback"
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
    db = Database.new
    db.addComment(comment)
    
    '<?xml version="1.0" encoding="utf-8"?>
    <response>
       <error>0</error>
     </response>'
end

post %r{/([0-9]+)/addComment} do |id|
    commentAuthor = CommentAuthor.new
    commentAuthor.name = params[:name]
    commentAuthor.mail = params[:mail]
    commentAuthor.url = params[:url]

    comment = Comment.new()
    comment.replyToComment = params[:replyToComment].empty? ? nil : params[:replyToComment]
    comment.replyToEntry = id
    comment.body = params[:body]
    comment.author = commentAuthor
    db = Database.new
    db.addComment(comment)
    "Done"
end

get  %r{/([0-9]+)/([\w]+)} do |id, title|
    entry = Entry.new(id)
    db = Database.new
    comments = db.getCommentsForEntry(id)
    erb :page, :locals => {:entry => entry, :comments => comments}
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