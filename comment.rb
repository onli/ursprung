class Comment
    attr_accessor :author
    attr_accessor :body
    attr_accessor :title
    attr_accessor :date
    attr_accessor :id
    attr_accessor :replyToComment
    attr_accessor :replyToEntry
    attr_accessor :type
    attr_accessor :status 

    def initialize()
        self.type = "comment"
        self.status = "approved"
        self.title = ""
        self.replyToComment = nil
    end

end