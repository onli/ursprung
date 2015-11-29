require "./entry.rb"
require "./database.rb"
require "test/unit"
 
class TestPagination < Test::Unit::TestCase

    def test_pagesizes
        db = Ursprung::Database.new
        db.databaseFile = ':memory:'
        db.setupDB
        db = Ursprung::Database.class_eval('@@db')
        db.execute "DELETE FROM entries;"
        db.execute "DELETE FROM pagination;"

        13.times do
            params = {:body => "Lorem ipsum", :title => "test"}
            begin   # this will throw erros as Ursprung::pool is not loaded, but save anyway
                Ursprung::Entry.new(params, nil)
            rescue; end
            sleep(1)
        end
        assert_equal(13, db.execute('SELECT COUNT(id) FROM entries')[0]['COUNT(id)'])
        assert_equal(5, db.execute('SELECT id FROM entries WHERE date <= (SELECT startDate FROM pagination WHERE page = 3) LIMIT 5').length)
        assert_equal(3, db.execute('SELECT id FROM entries WHERE date <= (SELECT startDate FROM pagination WHERE page = 2) AND date > (SELECT startDate FROM pagination WHERE page = 1)').length)
        assert_equal(5, db.execute('SELECT id FROM entries WHERE date <= (SELECT startDate FROM pagination WHERE page = 1)').length)
        db.execute "DELETE FROM entries;"
        db.execute "DELETE FROM pagination;"
    end

end