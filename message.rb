require './database.rb'
require './friend.rb'
require 'crypt/blowfish'
require 'securerandom'
require 'base64'

class Message
    attr_accessor :id
    attr_accessor :content
    attr_accessor :to
    attr_accessor :from
    attr_accessor :key
    attr_accessor :read

    def initialize(*args)
        case args.length
        when 1
            messageData = Database.new.getMessageData(args[0])
            self.id = messageData["id"]
            self.content = messageData["content"]
            self.to = messageData["recipient"]
            self.from = messageData["author"]
            self.key = messageData["key"]
            self.read = messageData["read"]
        when 2
            self.to = args[0]
            self.from = Database.new.getAdminMail
            self.key, self.content = self.encrypt(args[1])
            self.id = self.save
        when 4
            self.content = args[0]
            self.key =  args[1]
            self.from = args[2]
            self.to = args[3]

            self.id = self.save
        end
    end

    # encrypt the content of the message
    def encrypt(content)
        key = SecureRandom.hex(28)    #max bytesize is 56, but rubystring have 2 bytes per char
        blowfish = Crypt::Blowfish.new(key)
        return key, Base64.encode64(blowfish.encrypt_string(content))
    end

    # decrypt the content of the message
    def decryptContent()
        blowfish = Crypt::Blowfish.new(self.key)
        return blowfish.decrypt_string(Base64.decode64(self.content))
    end

    def save()
        return Database.new.addMessage(self)
    end

    def send()
        friend = Friend.new(self.to).send(self)
    end


end