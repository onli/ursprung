require 'sqlite3'

class Database

    def initialize 
        @db = SQLite3::Database.new "dsnblog.db"
        begin
            @db.execute "CREATE TABLE IF NOT EXISTS authors(
                            name TEXT PRIMARY KEY,
                            mail TEXT UNIQUE
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS options(
                            name TEXT PRIMARY KEY,
                            value TEXT
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS cache(
                            key TEXT PRIMARY KEY,
                            value TEXT,
                            ttl INTEGER DEFAULT (strftime('%s','now') + 604800)
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS friends(
                            name TEXT PRIMARY KEY,
                            url TEXT
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS comments(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            replyToEntry INTEGER,
                            replyToComment INTEGER,
                            name TEXT,
                            mail TEXT,
                            url TEXT,
                            body TEXT,
                            title TEXT,
                            type TEXT DEFAULT 'comment',
                            status TEXT DEFAULT 'approved',
                            subscribe INTEGER DEFAULT 0,
                            date INTEGER DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (replyToEntry) REFERENCES entries(id) ON DELETE CASCADE,
                            FOREIGN KEY (replyToComment) REFERENCES comments(id) 
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS entries(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            body TEXT,
                            title TEXT,
                            author TEXT,
                            moderate TEXT,
                            date INTEGER DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (author) REFERENCES authors(name) ON UPDATE CASCADE
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS stream(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            body TEXT,
                            title TEXT,
                            author TEXT,
                            date INTEGER,
                            url TEXT,
                            guid INTEGER,
                            FOREIGN KEY (author) REFERENCES friends(name) ON UPDATE CASCADE,
                            UNIQUE (author, guid)
                        );"
            begin
                @db.execute 'CREATE VIRTUAL TABLE search
                                USING fts4(content="entries", body, title);'
            rescue => error
                # if not exists should work here, but doesn't, so this always throws an error if table exists
            end
            @db.execute 'CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
                            INSERT INTO search(docid, body, title) VALUES(new.rowid, new.body, new.title);
                        END;'
            @db.execute 'CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
                            INSERT INTO search(docid, body, title) VALUES(new.rowid, new.body, new.title);
                        END;'
            @db.execute 'CREATE TRIGGER IF NOT EXISTS entries_bd BEFORE DELETE ON entries BEGIN
                            DELETE FROM search WHERE docid=old.rowid;
                        END;'
            @db.execute 'CREATE TRIGGER IF NOT EXISTS entries_bu BEFORE UPDATE ON entries BEGIN
                            DELETE FROM search WHERE docid=old.rowid;
                        END;'
            @db.execute "PRAGMA foreign_keys = ON;"
            @db.results_as_hash = true
        rescue => error
            puts "error creating tables: #{error}"
        end
    end

    def getEntries(page, amount)
        entries = []
        begin
            totalEntries = @db.execute("SELECT COUNT(id) from entries")[0]["COUNT(id)"]
        rescue => error
            puts "getEntries count: #{error}"
        end
        totalPages = (totalEntries.to_f / amount).ceil;
        totalPages = totalPages <= 0 ? 1 : totalPages
        case page
            when -1 then
                # on frontpage, we have no real index
                offset = 0
                limit = amount
            when totalPages - 1 then
                offset = amount
                limit = (totalEntries - ((totalPages - 2) * amount)) - amount
            else
                offset = totalEntries - (amount * page)
                limit = amount
        end
        begin
            @db.execute("SELECT id FROM entries ORDER BY date DESC LIMIT ?,?;", offset, limit) do |row|
                entry = Entry.new(row["id"])
                entries.push(entry)
            end
        rescue => error
            puts "getEntries: #{error}"
        end
        return entries
    end

    def getTotalPages()
        amount = 5
        totalEntries = @db.execute("SELECT COUNT(id) from entries")[0]["COUNT(id)"]
        totalPages = (totalEntries.to_f / amount).ceil;
    end

    def addEntry(entry)
        begin
            @db.execute("INSERT INTO entries(title, body, author) VALUES(?, ?, ?);", entry.title, entry.body, entry.author)
        rescue => error
            puts error
        end
        return @db.last_insert_row_id()
    end

    def editEntry(entry)
        begin
            @db.execute("UPDATE entries SET title = ?, body = ? WHERE id = ?;", entry.title, entry.body, entry.id)
        rescue => error
            puts error
            return false
        end
        return true
    end

    def deleteEntry(id)
        begin
            @db.execute("DELETE FROM entries WHERE id = ?", id)
        rescue => error
            puts "error in deleting entries: #{error}"
        end
    end

    def getEntryData(id)
        begin
            return @db.execute("SELECT title, body, author, date, moderate FROM entries WHERE id == ?;", id)[0]
        rescue => error
            puts "getEntryData: #{error}"
        end
    end

    def setEntryModeration(id, value)
        begin
            value = 1 if value == "true"
            value = 0 if value == "false"
            return @db.execute("UPDATE entries SET moderate = ? WHERE id = ?;", value, id)
        rescue => error
            puts "setEntryOption: #{error}"
        end
    end

    def addComment(comment)
        begin
             @db.execute("INSERT INTO comments(replyToEntry, replyToComment, body, type, status, title, name, mail, url, subscribe)
                            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
                            comment.replyToEntry, comment.replyToComment, comment.body, comment.type, comment.status,
                            comment.title, comment.author.name, comment.author.mail, comment.author.url, comment.subscribe)
        rescue => error
            puts "error in inserting comment: #{error}"
        end
    end

    def editComment(comment)
        begin
            @db.execute("UPDATE comments SET title = ?, body = ?, name = ?, url = ?, mail = ?, replyToComment = ?, status = ?, subscribe = ? WHERE id = ?;",
                        comment.title, comment.body, comment.author.name, comment.author.url, comment.author.mail, comment.replyToComment, comment.status, comment.subscribe, comment.id)
        rescue => error
            puts error
            return false
        end
        return true
    end

    def deleteComment(comment)
        puts "database comment delete"
        puts "id: #{comment.id}"
        begin
            @db.execute("DELETE FROM comments WHERE id = ?", comment.id)
        rescue => error
            puts "error in deleting comment: #{error}"
        end
    end

    def getCommentsForEntry(id)
        comments = []
        begin
            @db.execute("SELECT comments.id FROM comments WHERE replyToEntry == ?;", id) do  |row|
                comments.push(Comment.new(row["id"]))
            end
        rescue => error
            puts error
        end
        return comments
    end

    def getCommentData(id)
        begin
            return @db.execute("SELECT name, url, mail, body, title, replyToComment, replyToEntry, date, status, subscribe, type
                                FROM comments
                                WHERE comments.id == ?;", id)[0]
        rescue => error
            puts error
        end
    end

    def getMails()
        begin
            return @db.execute("SELECT mail FROM authors;")
        rescue => error
            puts error
        end
    end

    def firstUse?
        begin
            mail = @db.execute("SELECT mail FROM authors;")
        rescue => error
            puts error
        end
        return mail.empty?
    end

    def addUser(name, mail)
        begin
            mail = @db.execute("INSERT INTO authors(name, mail) VALUES(?, ?);", name, mail)
        rescue => error
            puts error
        end
    end
    
    def addFriend(name, url)
        begin
            mail = @db.execute("INSERT INTO friends(name, url) VALUES(?, ?);", name, url)
        rescue => error
            puts error
        end
    end

    def getFriends()
        friends = []
        begin
            @db.execute("SELECT name, url FROM friends;") do |row|
                friend = Friend.new()
                friend.name = row["name"]
                friend.url = row["url"]
                friends.push(friend)
            end
        rescue => error
            puts error
        end
        return friends
    end

    def getOption(name)
        begin
            return @db.execute("SELECT value FROM options WHERE name = ? LIMIT 1;", name)[0]['value']
        rescue => error
            puts "error getting option: #{error}"
            return "default" if name == "design"
        end
    end

    def setOption(name, value)
        begin
            @db.execute("INSERT OR IGNORE INTO options(name, value) VALUES(?, ?)", name, value)
            @db.execute("UPDATE options SET value = ? WHERE name = ?", value, name)
        rescue => error
            puts error
        end
    end

    def cache(key, value)
        begin
            @db.execute("INSERT OR IGNORE INTO cache(key, value) VALUES(?, ?)", key, value)
            @db.execute("UPDATE cache SET value = ?, ttl = (strftime('%s','now') + 604800) WHERE key = ?", value, key)
        rescue => error
            puts error
        end
    end

    def getCache(key)
        begin
            return @db.execute("SELECT value FROM cache WHERE key = ? AND ttl > strftime('%s','now') LIMIT 1;", key)[0]['value']
        rescue => error
            puts error
        end
    end

    # delete from cache all pages, but not linktitles
    def invalidateCache()
        begin
            return @db.execute("DELETE FROM cache WHERE key LIKE '/%'")
        rescue => error
            puts error
        end
    end
    
    def getAdmin()
        begin
            return @db.execute("SELECT name FROM authors LIMIT 1;")[0]['name']
        rescue => error
            puts error
        end
    end

    def getAdminMail()
        begin
            admin = self.getAdmin()
            return @db.execute("SELECT mail FROM authors WHERE name = ? LIMIT 1;", admin)[0]['mail']
        rescue => error
            puts error
        end
    end

    # get amount of last comments
    def getComments(amount)
        comments = []
        begin
            @db.execute("SELECT comments.id FROM comments ORDER BY date DESC LIMIT ?;", amount) do  |row|
                comments.push(Comment.new(row["id"]))
            end
        rescue => error
            puts error
        end
        return comments
    end

    def searchEntries(keyword)
        entries = []
        @db.execute("SELECT docid FROM search WHERE search MATCH ?;", keyword) do |row|
            entries.push(Entry.new(row["docid"]))
        end
        return entries
    end

end
