require 'classifier'
require 'madeleine'
require 'pony'

class Comment
    attr_accessor :author
    attr_accessor :body
    # important for trackbacks:
    attr_accessor :title
    attr_accessor :date
    attr_accessor :id
    attr_accessor :replyToComment
    attr_accessor :replyToEntry
    attr_accessor :type
    attr_accessor :status 
    attr_accessor :subscribe
    attr_accessor :validTrackback

    def initialize(*args)
        if args.length == 1 && args[0].respond_to?("even?")
            initializeFromID(args[0])
        else
            if args[0].respond_to?("merge")
                # creating comment from hash
                params = args[0]
                request = args[1]
                commentAuthor = CommentAuthor.new
                commentAuthor.name = Sanitize.clean(params[:name])
                commentAuthor.mail = Sanitize.clean(params[:mail])
                commentAuthor.url = Sanitize.clean(params[:url])

                begin
                    self.replyToComment = params[:replyToComment].empty? ? nil : params[:replyToComment]
                rescue
                    self.replyToComment = nil
                end
                self.replyToEntry = params[:entryId]
                self.body = HTMLEntities.new.encode(params[:body])
                self.author = commentAuthor
                self.id = params[:id] if params[:id] != nil
                self.status = "approved"
                self.status = "moderate" if self.isSpam? or self.entry.moderate
                self.subscribe = 1 if params[:subscribe] != nil
                self.type = params[:type] if params[:type] != nil
                if self.type == "trackback"
                    name = getPingbackData(request)
                    if name
                        if self.body == ""
                            # it is a pingback, which needs to use the additional data
                            commentAuthor.name = name
                            self.author = commentAuthor
                        end
                        self.save
                        self.validTrackback = true
                    else
                        self.validTrackback = false
                    end
                else
                    self.save
                    self.validTrackback = true
                end
            end
        end
    end

    def initializeFromID(id)
        db = Database.new
        commentData = db.getCommentData(id)
        self.id = id
        self.body = commentData["body"]
        self.date = commentData["date"]
        self.title = commentData["date"]
        self.replyToComment = commentData["replyToComment"]
        self.replyToEntry = commentData["replyToEntry"]
        self.type = commentData["type"]
        self.status = commentData["status"]
        commentAuthor = CommentAuthor.new
        commentAuthor.name = commentData["name"]
        commentAuthor.mail = commentData["mail"]
        commentAuthor.url = commentData["url"]
        self.author = commentAuthor
    end

    def save()
        db = Database.new
        if self.id == nil
            # it is a new comment
            db.addComment(self)
            mailOwner()
            if (self.status == "approved")
                mailSubscribers()
            end
        else
            db.editComment(self)
        end
    end

    def delete()
        db = Database.new
        db.deleteComment(self)
    end

    def spam()
        m = SnapshotMadeleine.new("bayes_data") {
            Classifier::Bayes.new "Spam", "Ham"
        }
        [self.body, self.author.name, self.author.mail, self.author.url].each do |commentPart|
            begin
                m.system.train_spam commentPart
            rescue
            end
        end
        m.take_snapshot
    end
    
    def ham()
        self.status = "approved"
        m = SnapshotMadeleine.new("bayes_data") {
            Classifier::Bayes.new "Spam", "Ham"
        }
        [self.body, self.author.name, self.author.mail, self.author.url].each do |commentPart|
            begin
                m.system.train_ham commentPart
            rescue
            end
        end
        m.take_snapshot
        self.save
    end

    def isSpam?()
        m = SnapshotMadeleine.new("bayes_data") {
            Classifier::Bayes.new "Spam", "Ham"
        }
        return (m.system.classify "#{self.author.name} #{self.author.mail} #{self.author.url} #{self.body}") == "Spam"
    end

    def entry() 
        return Entry.new(self.replyToEntry)
    end

    def mailOwner()
        db = Database.new
        begin
            Pony.mail(:to => db.getAdminMail,
                  :from => db.getOption("fromMail"),
                  :subject => "#{db.getOption("blogTitle")}: #{self.author.name} commented on #{Entry.new(self.replyToEntry).title}",
                  :body => "He wrote: #{self.body}"
                  )
        rescue Errno::ECONNREFUSED => e
            puts "Error mailing owner: #{e}"
        end
    end

    def mailSubscribers()
        db = Database.new
        fromMail = db.getOption("fromMail")
        blogTitle = db.getOption("blogTitle")
        if fromMail && fromMail != "" 
            db.getCommentsForEntry(Entry.new(self.replyToEntry)).each do |comment|
                if comment.subscribe && comment.author.mail && comment != self
                    begin
                        Pony.mail(:to => comment.author.mail,
                              :from => fromMail,
                              :subject => "#{blogTitle}: #{self.author.name} commented on #{Entry.new(self.replyToEntry).title}",
                              :body => "He wrote: #{self.body}"
                              )
                    rescue Errno::ECONNREFUSED => e
                        puts "Error mailing subscribers: #{e}"
                    end
                end
            end
        end
    end

    # If a valid link exists, gather the data to format the pingback. Else return false
    def getPingbackData(request)
        uri = URI.parse(self.author.url)
        http = Net::HTTP.new(uri.host, uri.port)
        http_request = Net::HTTP::Get.new(uri.request_uri)

        response = http.request(http_request)
        doc = Nokogiri::HTML(response.body)
        title = doc.title
        
        doc.css("a").map do |link|
            if (href = link.attr("href")) && href.match(/#{self.entry.link(request)}.*/)
                return title
            end
        end.compact

        return false
    end

    def avatar
        if self.author.mail
            require 'digest/md5'
            return "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(self.author.mail.downcase)}?d=mm&s=40"
        else
            return nil
        end
    end

    def format
        def format()
        formattedBody = self.body
        formattedBody = formattedBody.gsub(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
        formattedBody = formattedBody.gsub(/\*(.*?)\*/, '<em>\1</em>')
        # link without name:
        formattedBody = formattedBody.gsub(/\[([^ ]*?)\]/, '<a href="\1">\1</a>')
        # link: [url name]
        formattedBody = formattedBody.gsub(/\[(.*?) (.*?)\]/, '<a href="\1">\2</a>')
        return formattedBody.gsub("\n", "<br>\n")
    end
    end
end