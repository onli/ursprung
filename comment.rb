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

    def initialize(*args)
        if args.length == 1
            initializeFromID(args[0])
        else
            # TODO: Dont hardcode those values
            self.type = "comment"
            self.status = "approved"
            self.replyToComment = nil
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
            if (comment.status == "approved")
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
        m.system.train_spam self.body
        m.system.train_spam self.author.name
        m.system.train_spam self.author.mail
        m.system.train_spam self.author.url
        m.take_snapshot
    end
    
    def ham()
        self.status = "approved"
        m = SnapshotMadeleine.new("bayes_data") {
            Classifier::Bayes.new "Spam", "Ham"
        }
        m.system.train_ham self.body
        m.system.train_ham self.author.name
        m.system.train_ham self.author.mail
        m.system.train_ham self.author.url
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
        Pony.mail(:to => db.getAdminMail,
                  :from => db.getOption("fromMail"),
                  :subject => "#{db.getOption("blogTitle")}: #{self.author.name} commented on #{Entry.new(self.replyToEntry).title}",
                  :body => "He wrote: #{self.body}"
                  )
    end

    def mailSubscribers()
        db = Database.new
        fromMail = db.getOption("fromMail")
        blogTitle = db.getOption("blogTitle")
        if fromMail && fromMail != "" 
            db.getCommentsForEntry(Entry.new(self.replyToEntry)).each do |comment|
                if comment.subscribe && comment.author.mail && comment != self
                    Pony.mail(:to => comment.author.mail,
                              :from => fromMail,
                              :subject => "#{blogTitle}: #{self.author.name} commented on #{Entry.new(self.replyToEntry).title}",
                              :body => "He wrote: #{self.body}"
                              )
                end
            end
        end
    end

end