require 'classifier'
require 'madeleine'
require 'pony'
require 'kramdown'

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
        case args.length
        when 1
            initializeFromID(args[0])
        when 2
            # creating comment from hash
            params = args[0]
            request = args[1]
            return if params[:tel] && params[:tel] != "" # the honeypot
            commentAuthor = CommentAuthor.new
            commentAuthor.name = Sanitize.clean(params[:name].strip)
            commentAuthor.name = "Anonymous" if commentAuthor.name == ""
            commentAuthor.mail = Sanitize.clean(params[:mail].strip)
            commentAuthor.url = Sanitize.clean(params[:url].strip)
            begin
                self.replyToComment = params[:replyToComment].empty? ? nil : params[:replyToComment]
            rescue
                # this can happen if we are getting a track/pingback
                self.replyToComment = nil
            end
            self.replyToEntry = params[:entryId]
            if self.entry.moderate == "closed"
                return
            end
            self.body = HTMLEntities.new.encode(params[:body])
            self.author = commentAuthor
            self.id = params[:id]
            self.status = "approved"
            self.status = "moderate" if self.isSpam? || self.entry.moderate == "moderate"
            self.subscribe = 1 if params[:subscribe] != nil
            self.type = params[:type]
            if self.type == "trackback"
                name = getPingbackData(request)
                if name
                    if self.body == ""
                        # it is a pingback, which needs to use the additional data
                        commentAuthor.name = name
                        self.author = commentAuthor
                    end
                    self.save(request)
                    self.validTrackback = true
                else
                    self.validTrackback = false
                end
            else
                self.save(request)
                self.validTrackback = true
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
        self.subscribe = commentData["subscribe"]
        commentAuthor = CommentAuthor.new
        commentAuthor.name = commentData["name"]
        commentAuthor.mail = commentData["mail"]
        commentAuthor.url = commentData["url"]
        self.author = commentAuthor
    end

    def save(request)
        db = Database.new
        if self.id == nil
            # it is a new comment
            db.addComment(self)
            mailOwner(request)
            if (self.status == "approved")
                mailSubscribers(request)
            end
        else
            db.editComment(self)
        end
        db.invalidateCache(self)
    end

    def delete()
        db = Database.new
        db.deleteComment(self)
        db.invalidateCache(self)
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

    def mailOwner(request)
        db = Database.new
        begin
            entry = self.entry
            Pony.mail(:to => db.getAdminMail,
                  :from => db.getOption("fromMail"),
                  :subject => "#{db.getOption("blogTitle")}: #{self.author.name} commented on #{entry.title}",
                  :body => "He wrote: \n\n#{self.body}\n\nLink: #{entry.link(request)}"
                  )
        rescue Errno::ECONNREFUSED => e
            warn "Error mailing owner: #{e}"
        end
    end

    def mailSubscribers(request)
        db = Database.new
        fromMail = db.getOption("fromMail")
        if fromMail && fromMail != ""
            blogTitle = db.getOption("blogTitle")
            mailDelivered = []
            entry = self.entry
            db.getCommentsForEntry(self.replyToEntry).each do |comment|
                if comment.subscribe && comment.author.mail && comment != self && ! mailDelivered.include?(comment.author.mail) && comment.author.mail != db.getAdminMail
                    begin
                        cipher = OpenSSL::Cipher::Cipher.new('bf-cbc').send(:encrypt)
                        cipher.key = Digest::SHA256.digest(db.getOption("secret"))
                        encrypted = cipher.update(comment.author.mail) << cipher.final
                        Pony.mail(:to => comment.author.mail,
                              :from => fromMail,
                              :subject => "#{blogTitle}: #{self.author.name} commented on #{Entry.new(self.replyToEntry).title}",
                              :body => "He wrote: #{self.body}\n\nLink: #{entry.link(request)}\n\nLink: #{entry.link(request)}\n\nUnsubscribe: http://#{request.host_with_port}/subscriptions/#{URI.escape(encrypted)}"
                              )
                        mailDelivered.push(comment.author.mail)
                    rescue Errno::ECONNREFUSED => e
                        warn "Error mailing subscribers: #{e}"
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

    def avatar()
        if self.author.mail
            return "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(self.author.mail.downcase)}?d=mm&s=40"
        else
            return nil
        end
    end

    def format()
        return Kramdown::Document.new(  self.body.gsub(
                                            /&gt;&gt;([0-9]*)/,
                                            '<a class="commentReference" href="#c\1">&gt;&gt;\1</a>  '
                                        ),
                                        :auto_ids => false,
                                        :hard_wrap => true
                                    ).to_html
    end
end