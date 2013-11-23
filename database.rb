require 'sqlite3'

class Database

    def initialize
        begin
            @@db    # create a singleton - if this class-variable is uninitialized, this will fail and can then be initialized
        rescue
            @@db = SQLite3::Database.new "dsnblog.db"
            begin
                @@db.execute "CREATE TABLE IF NOT EXISTS authors(
                                name TEXT PRIMARY KEY,
                                mail TEXT UNIQUE
                                );"
                @@db.execute "CREATE TABLE IF NOT EXISTS options(
                                name TEXT PRIMARY KEY,
                                value TEXT
                                );"
                @@db.execute "CREATE TABLE IF NOT EXISTS cache(
                                key TEXT PRIMARY KEY,
                                value TEXT,
                                ttl INTEGER DEFAULT (strftime('%s','now') + 604800)
                                );"
                @@db.execute "CREATE TABLE IF NOT EXISTS friends(
                                name TEXT PRIMARY KEY,
                                url TEXT
                                );"
                @@db.execute "CREATE TABLE IF NOT EXISTS comments(
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
                @@db.execute "CREATE TABLE IF NOT EXISTS entries(
                                id INTEGER PRIMARY KEY AUTOINCREMENT,
                                body TEXT,
                                title TEXT,
                                author TEXT,
                                moderate TEXT,
                                date INTEGER DEFAULT CURRENT_TIMESTAMP,
                                deleted INTEGER DEFAULT 0,
                                FOREIGN KEY (author) REFERENCES authors(name) ON UPDATE CASCADE
                                );"
                @@db.execute "CREATE TABLE IF NOT EXISTS tags(
                                tag TEXT,
                                entryId INTEGER,
                                FOREIGN KEY (entryId) REFERENCES entries(id) ON UPDATE CASCADE ON DELETE CASCADE
                );"
                @@db.execute "CREATE INDEX IF NOT EXISTS tags_tag_index ON tags(tag)"
                @@db.execute "CREATE TABLE IF NOT EXISTS entries_recycler
                                AS
                                SELECT * from entries WHERE id == -1;"
                @@db.execute "CREATE TABLE IF NOT EXISTS tags_recycler
                                AS
                                SELECT * from tags WHERE entryId == -1;"
                begin
                    @@db.execute 'CREATE VIRTUAL TABLE search
                                    USING fts4(content="entries", body, title);'
                rescue => error
                    # if not exists should work here, but doesn't, so this always throws an error if table exists
                    warn "Creating search-table: #{error}"
                end
                @@db.execute 'CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
                                INSERT INTO search(docid, body, title) VALUES(new.rowid, new.body, new.title);
                            END;'
                @@db.execute 'CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
                                INSERT INTO search(docid, body, title) VALUES(new.rowid, new.body, new.title);
                            END;'
                @@db.execute 'CREATE TRIGGER IF NOT EXISTS entries_bd BEFORE DELETE ON entries BEGIN
                                DELETE FROM search WHERE docid=old.rowid;
                            END;'
                @@db.execute 'CREATE TRIGGER IF NOT EXISTS entries_bu BEFORE UPDATE ON entries BEGIN
                                DELETE FROM search WHERE docid=old.rowid;
                            END;'
                @@db.execute "PRAGMA foreign_keys = ON;"
                @@db.results_as_hash = true
            rescue => error
                warn "error creating tables: #{error}"
            end
        end
    end

    def getEntries(page, amount, tag)
        entries = []
        totalPages, totalEntries = self.getTotalPages(amount, tag)
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
            if tag == nil
                @@db.execute("SELECT id FROM entries WHERE deleted != 1 ORDER BY date DESC LIMIT ?,?;", offset, limit) do |row|
                    entry = Entry.new(row["id"])
                    entries.push(entry)
                end
            else
                @@db.execute("SELECT id FROM entries WHERE deleted != 1 AND id IN (SELECT entryId FROM tags WHERE tag = ?) ORDER BY date DESC LIMIT ?,?;", tag, offset, limit) do |row|
                    entry = Entry.new(row["id"])
                    entries.push(entry)
                end
            end
        rescue => error
            warn "getEntries: #{error}"
        end
        return entries
    end

    def getAllTags()
        begin
            tags = []
            @@db.execute("SELECT DISTINCT tag FROM tags") do |row|
                tags.push(row["tag"])
            end
            return tags
        rescue => error
            warn "getAllTags: #{error}"
        end
    end

    def getTotalPages(amount, tag)
        begin
            if tag == nil
                totalEntries = @@db.execute("SELECT COUNT(id) from entries")[0]["COUNT(id)"]
            else
                totalEntries = @@db.execute("SELECT COUNT(DISTINCT entryId) from tags WHERE tag = ?", tag)[0]["COUNT(DISTINCT entryId)"]
            end
        rescue => error
            warn "getEntries count: #{error}"
        end
        totalPages = (totalEntries.to_f / amount).ceil;
        return totalPages, totalEntries
    end

    def getAllEntryIds()
        begin
            return @@db.execute("SELECT id from entries")
        rescue => error
            warn "getAllEntryIds: #{error}"
        end
    end

    def addEntry(entry)
        begin
            @@db.execute("INSERT INTO entries(title, body, author) VALUES(?, ?, ?);", entry.title, entry.body, entry.author)
        rescue => error
            warn "addEntry1: #{error}"
        end
        id = @@db.last_insert_row_id()
        begin
            entry.tags.each do |tag|
                @@db.execute("INSERT INTO tags(tag, entryId) VALUES(?, ?);", tag, id)
            end
        rescue => error
            warn "addEntry2: #{error}"
        end
        return id
    end

    def editEntry(entry)
        begin
            @@db.execute("UPDATE entries SET title = ?, body = ?, deleted = 0 WHERE id = ?;", entry.title, entry.body, entry.id)
            @@db.execute("DELETE FROM tags WHERE entryId = ?;", entry.id)
            entry.tags.each do |tag|
                @@db.execute("INSERT INTO tags(tag, entryId) VALUES(?, ?);", tag, entry.id)
            end
        rescue => error
            warn "editEntry: #{error}"
            return false
        end
        return true
    end

    def deleteEntry(id)
        begin
            @@db.execute("DELETE FROM entries WHERE id = ?", id)
            @@db.execute("DELETE FROM tags WHERE entryId = ?;", id)
        rescue => error
            warn "deleteEntry: #{error}"
        end
    end

    def deleteEntrySoft(id)
        begin
            @@db.execute("UPDATE entries SET deleted = 1 WHERE id == ?;", id)
        rescue => error
            warn "deleteEntrySoft: #{error}"
        end
    end

    def deleteStoredEntries()
        begin
            @@db.execute("DELETE FROM entries WHERE deleted == 1;")
        rescue => error
            warn "deleteStoredEntries: #{error}"
        end
    end

    def getEntryData(id, deleted)
        begin
            if deleted
                entryData = @@db.execute("SELECT title, body, author, date, moderate FROM entries WHERE id == ?;", id)[0]
            else
                entryData = @@db.execute("SELECT title, body, author, date, moderate FROM entries WHERE id == ? AND deleted != 1;", id)[0]
            end
            tags = []
            @@db.execute("SELECT tag FROM tags WHERE entryId == ?;", id) do |row|
                tags.push(row["tag"])
            end
            entryData["tags"] = tags
        rescue => error
            warn "getEntryData: #{error}"
        end
        return entryData
    end

    def setEntryModeration(id, value)
        begin
            return @@db.execute("UPDATE entries SET moderate = ? WHERE id = ?;", value, id)
        rescue => error
            warn "setEntryModeration: #{error}"
        end
    end

    def addComment(comment)
        begin
            @@db.execute("INSERT INTO comments(replyToEntry, replyToComment, body, type, status, title, name, mail, url, subscribe)
                            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
                            comment.replyToEntry, comment.replyToComment, comment.body, comment.type, comment.status,
                            comment.title, comment.author.name, comment.author.mail, comment.author.url, comment.subscribe)
        rescue => error
            warn "addComment: #{error}"
        end
    end

    def editComment(comment)
        begin
            @@db.execute("UPDATE comments SET title = ?, body = ?, name = ?, url = ?, mail = ?, replyToComment = ?, status = ?, subscribe = ? WHERE id = ?;",
                        comment.title, comment.body, comment.author.name, comment.author.url, comment.author.mail, comment.replyToComment, comment.status, comment.subscribe, comment.id)
        rescue => error
            warn "editComment: #{error}"
            return false
        end
        return true
    end

    def deleteComment(comment)
        begin
            @@db.execute("DELETE FROM comments WHERE id = ?", comment.id)
        rescue => error
            warn "deleteComment: #{error}"
        end
    end

    def getCommentsForEntry(id)
        comments = []
        begin
            @@db.execute("SELECT comments.id FROM comments WHERE replyToEntry == ?;", id) do  |row|
                comments.push(Comment.new(row["id"]))
            end
        rescue => error
            warn "getCommentsForEntry #{error}"
        end
        return comments
    end

    def getCommentData(id)
        begin
            return @@db.execute("SELECT name, url, mail, body, title, replyToComment, replyToEntry, date, status, subscribe, type
                                FROM comments
                                WHERE comments.id == ?;", id)[0]
        rescue => error
            warn "getCommentData #{error}"
        end
    end

    def getMails()
        begin
            return @@db.execute("SELECT mail FROM authors;")
        rescue => error
            warn "getMails: #{error}"
        end
    end

    def firstUse?
        begin
            mail = @@db.execute("SELECT mail FROM authors;")
        rescue => error
            warn "firstUse?: #{error}"
        end
        return mail.empty?
    end

    def addUser(name, mail)
        begin
            mail = @@db.execute("INSERT INTO authors(name, mail) VALUES(?, ?);", name, mail)
        rescue => error
            warn "addUser: #{error}"
        end
    end
    
    def addFriend(friend)
        begin
            @@db.execute("INSERT INTO friends(name) VALUES(?);", friend.name)
            return true
        rescue => error
            warn "addFried: #{error}"
            return false
        end
    end

    def getFriends()
        friends = []
        begin
            @@db.execute("SELECT name FROM friends;") do |row|
                friend = Friend.new()
                friend.name = row["name"]
                friends.push(friend)
            end
        rescue => error
            warn "getFriends: #{error}"
        end
        return friends
    end

    def getOption(name)
        begin
            return @@db.execute("SELECT value FROM options WHERE name = ? LIMIT 1;", name)[0]['value']
        rescue => error
            warn "getOption: #{error}"
            return "default" if name == "design"
        end
    end

    def setOption(name, value)
        begin
            @@db.execute("INSERT OR IGNORE INTO options(name, value) VALUES(?, ?)", name, value)
            @@db.execute("UPDATE options SET value = ? WHERE name = ?", value, name)
        rescue => error
            warn "setOption: #{error}"
        end
    end

    def cache(key, value)
        begin
            @@db.execute("INSERT OR IGNORE INTO cache(key, value) VALUES(?, ?)", key, value)
            @@db.execute("UPDATE cache SET value = ?, ttl = (strftime('%s','now') + 604800) WHERE key = ?", value, key)
        rescue => error
            warn "cache: #{error}"
        end
    end

    # get cache content and moment of creation
    def getCache(key)
        begin
            cached = @@db.execute("SELECT value, ttl FROM cache WHERE key = ? AND ttl > strftime('%s','now') LIMIT 1;", key)[0]
            return cached['value'], (cached['ttl'] - 604800)
        rescue => error
            warn "getCache: #{error}"
        end
    end

    # delete from cache all pages, but not linktitles
    def invalidateCache(origin)
        case origin.class.to_s
        when "NilClass"
            begin
                return @@db.execute("DELETE FROM cache WHERE key LIKE '/%'")
            rescue => error
                warn "invalidateCache complete: #{error}"
            end
        when "Entry"
            begin
                archivePage = origin.archivePage.to_s
                amount = 5
                @@db.execute("DELETE FROM cache WHERE key LIKE '/||==||%'") if archivePage == self.getTotalPages(amount, nil).to_s
                # origin.id and archivePage throw a bind or column index out of range error when inserted properly
                @@db.execute("DELETE FROM cache WHERE key LIKE '/#{SQLite3::Database.quote origin.id.to_s}/%'
                                                                OR key LIKE '/archive/#{SQLite3::Database.quote archivePage}/||==||%'
                                                                " + (origin.tags.map{|tag| "OR key LIKE 'archive/%/"+ SQLite3::Database.quote(tag) +"/%'"}.join(" ")) +"
                                                                OR key LIKE '/search/%'
                                                                    ")
                                                                    
            rescue => error
                warn "invalidateCache for entry: #{error}"
            end
        when "Comment"
            begin
                # throws a bind or column index out of range error when inserted properly as well
                @@db.execute("DELETE FROM cache WHERE key LIKE '/#{SQLite3::Database.quote origin.replyToEntry}/%'")
            rescue => error
                warn "invalidateCache for comment: #{error}"
            end
        end
    
    end
    
    def getAdmin()
        begin
            return @@db.execute("SELECT name FROM authors LIMIT 1;")[0]['name']
        rescue => error
            warn "getAdmin: #{error}"
        end
    end

    def getAdminMail()
        begin
            admin = self.getAdmin()
            return @@db.execute("SELECT mail FROM authors WHERE name = ? LIMIT 1;", admin)[0]['mail']
        rescue => error
            warn "getAdminMail: #{error}"
        end
    end

    # get amount of last comments
    def getComments(amount)
        comments = []
        begin
            @@db.execute("SELECT comments.id FROM comments ORDER BY date DESC LIMIT ?;", amount) do  |row|
                comments.push(Comment.new(row["id"]))
            end
        rescue => error
            warn "getComments: #{error}"
        end
        return comments
    end

    def searchEntries(keyword)
        entries = []
        @@db.execute("SELECT docid FROM search WHERE search MATCH ?;", keyword) do |row|
            entries.push(Entry.new(row["docid"]))
        end
        return entries
    end

    def getEntriesSubscribed(mail)
        entries = []
        begin
            @@db.execute("SELECT DISTINCT replyToEntry FROM comments where mail == ?;", mail) do  |row|
                entries.push(Entry.new(row["replyToEntry"]))
            end
        rescue => error
            warn "getEntriesSubscribed: #{error}"
        end
        return entries
    end
end
