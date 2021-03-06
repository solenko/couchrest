require File.expand_path("../../spec_helper", __FILE__)

describe CouchRest::Server do
  
  let :server do
    CouchRest::Server.new(COUCHHOST)
  end

  let :mock_server do
    CouchRest::Server.new("http://mock")
  end

  describe "#initialize" do
    it "should prepare frozen URI object" do
      expect(server.uri).to be_a(URI)
      expect(server.uri).to be_frozen
      expect(server.uri.to_s).to eql(COUCHHOST)
    end

    it "should clean URI" do
      server = CouchRest::Server.new(COUCHHOST + "/some/path?q=1#fragment")
      expect(server.uri.to_s).to eql(COUCHHOST)
    end
  end

  describe :connection do

    it "should be provided" do
      expect(server.connection).to be_a(CouchRest::Connection)
    end

    it "should cache connection in current thread" do
      server.connection # instantiate
      conns = Thread.current['couchrest.connections']
      expect(server.connection).to eql(conns[COUCHHOST])
    end

  end

  describe :databases do

    it "should provide list of databse names" do
      expect(server.databases).to include(TESTDB)
    end

  end

  describe :database do

    it "should instantiate a new database object" do
      db = server.database(TESTDB)
      expect(db).to be_a(CouchRest::Database)
      expect(db.name).to eql(TESTDB)
    end

  end

  describe :database! do

    let :db_name do
      TESTDB + '_create'
    end

    it "should instantiate and create database if it doesn't exist" do
      db = server.database!(db_name)
      expect(server.databases).to include(db_name)
      db.delete!
    end

  end

  describe :info do

    it "should provide server info" do
      expect(server.info).to be_a(Hash)
      expect(server.info).to include('couchdb')
      expect(server.info['couchdb']).to eql('Welcome')
    end

  end

  describe :restart do
    it "should send restart request" do
      # we really do not need to perform a proper restart!
      stub_request(:post, "http://mock/_restart")
        .to_return(:body => "{\"ok\":true}")
      mock_server.restart!
    end
  end

  describe :next_uuid do
    it "should provide one-time access to uuids" do
      expect(server.next_uuid).not_to be_nil
    end

    it "should support providing batch count" do
      server.next_uuid(10)
      expect(server.uuids.length).to eql(9)
    end
  end

end
