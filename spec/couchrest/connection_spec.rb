require File.expand_path("../../spec_helper", __FILE__)

describe CouchRest::Connection do

  let(:simple_response) { "{\"ok\":true}" }
  let(:parser) { MultiJson }
  let(:parser_opts) { {:max_nesting => false} }

  it "should exist" do
    conn = CouchRest::Connection.new(URI "http://localhost:5984")
    expect(conn).to respond_to :get
    expect(conn).to respond_to :put
    expect(conn).to respond_to :post
    expect(conn).to respond_to :copy
    expect(conn).to respond_to :delete
    expect(conn).to respond_to :head
  end

  describe "initialization" do

    it "should not modify the provided URI" do
      uri = URI("http://localhost:5984/path/random?query=none#fragment")
      s = uri.to_s
      CouchRest::Connection.new(uri)
      expect(uri.to_s).to eql(s)
    end

    it "should raise an error if not instantiated with a URI" do
      expect { CouchRest::Connection.new("http://localhost:5984") }.to raise_error(/URI::HTTP/)
    end

    it "should clean the provided URI" do
      conn = CouchRest::Connection.new(URI "http://localhost:5984/path/random?query=none#fragment")
      expect(conn.uri.to_s).to eql("http://localhost:5984")
    end

    it "should have instantiated an HTTP connection" do
      conn = CouchRest::Connection.new(URI "http://localhost:5984")
      expect(conn.http).to be_a(Net::HTTP::Persistent)
    end
    
    describe "with SSL options" do
      it "should leave the default if nothing set" do
        default = Net::HTTP::Persistent.new('test').verify_mode
        conn = CouchRest::Connection.new(URI "https://localhost:5984")
        expect(conn.http.verify_mode).to eql(default)
      end
      it "should support disabling SSL verify mode" do
        conn = CouchRest::Connection.new(URI("https://localhost:5984"), :verify_ssl => false)
        expect(conn.http.verify_mode).to eql(OpenSSL::SSL::VERIFY_NONE)
      end
      it "should support enabling SSL verify mode" do
        conn = CouchRest::Connection.new(URI("https://localhost:5984"), :verify_ssl => true)
        expect(conn.http.verify_mode).to eql(OpenSSL::SSL::VERIFY_PEER)
      end
      it "should support setting specific cert, key, and ca" do
        conn = CouchRest::Connection.new(URI("https://localhost:5984"),
          :ssl_client_cert => 'cert',
          :ssl_client_key  => 'key',
          :ssl_ca_file     => 'ca_file'
        )
        expect(conn.http.certificate).to eql('cert')
        expect(conn.http.private_key).to eql('key')
        expect(conn.http.ca_file).to eql('ca_file')
      end

    end

    describe "with timeout options" do
      it "should be set on the http object" do
        conn = CouchRest::Connection.new(URI("https://localhost:5984"),
                                         :timeout => 23,
                                         :open_timeout => 26
                                        )

        expect(conn.http.read_timeout).to eql(23)
        expect(conn.http.open_timeout).to eql(26)
      end
      it "should support read_timeout" do
        conn = CouchRest::Connection.new(URI("https://localhost:5984"),
                                         :read_timeout => 25
                                        )
        expect(conn.http.read_timeout).to eql(25)
      end 
    end
  
  end

  describe "basic requests" do

    let :doc do
      { '_id' => 'test-doc', 'name' => 'test document' }
    end
    let :uri do
      URI(DB.to_s + "/test-doc")
    end
    let :conn do
      CouchRest::Connection.new(uri)
    end
    let :mock_conn do
      CouchRest::Connection.new(URI "http://mock")
    end

    describe :get do
      

      it "should send basic request" do
        DB.save_doc(doc)
        res = conn.get(uri.path)
        expect(res['name']).to eql(doc['name'])
      end

      it "should raise exception if document missing" do
        uri = URI(DB.to_s + "/missingdoc")
        conn = CouchRest::Connection.new(uri)
        res = nil
        expect { res = conn.get(uri.path) }.to raise_error do |e|
          expect(e).to be_a(CouchRest::RequestFailed)
          expect(e).to be_a(CouchRest::NotFound)
          expect(e.response).to eql(res)
        end
      end

      it "should handle 'content_type' header" do
        stub_request(:get, "http://mock/db/test")
          .with(:headers => {'content-type' => 'fooo'})
          .to_return(:body => doc.to_json)
        mock_conn.get("db/test", :content_type => 'fooo')
      end

      it "should handle 'accept' header" do
        stub_request(:get, "http://mock/db/test")
          .with(:headers => {'accept' => 'fooo'})
          .to_return(:body => doc.to_json)
        mock_conn.get("db/test", :accept => 'fooo')
      end

      it "should not overwrite 'Content-Type' header if provided" do
        stub_request(:get, "http://mock/db/test")
          .with(:headers => {'Content-Type' => 'fooo'})
          .to_return(:body => doc.to_json)
        mock_conn.get("db/test", :headers => { 'Content-Type' => 'fooo' })
      end

      it "should not overwrite 'Accept' header if provided in headers" do
        stub_request(:get, "http://mock/db/test")
          .with(:headers => {'Accept' => 'fooo'})
          .to_return(:body => doc.to_json)
        mock_conn.get("db/test", :headers => { 'Accept' => 'fooo' })
      end

      it "should convert 'Content-Type' header options" do
        stub_request(:get, "http://mock/db/test")
          .with(:headers => {'Content-Type' => 'application/json'})
          .to_return(:body => doc.to_json)
        mock_conn.get("db/test", :content_type => :json)
      end

      it "should maintain query parameters" do
        stub_request(:get, "http://mock/db/test?q=a")
          .to_return(:body => doc.to_json)
        expect(mock_conn.get("db/test?q=a")).to eql(doc)
      end

      it "should not try to parse result with :raw parameter" do
        json = doc.to_json
        stub_request(:get, "http://mock/db/test")
          .to_return(:body => json)
        expect(mock_conn.get("db/test", :raw => true)).to eql(json)
      end

      it "should forward parser options" do
        expect(MultiJson).to receive(:load).with(doc.to_json, hash_including(:max_nesting => true))
        stub_request(:get, "http://mock/db/test")
          .to_return(:body => doc.to_json)
        mock_conn.get("db/test", :max_nesting => true)
      end

      it "should forward parser options (2)" do
        expect(MultiJson).to receive(:load).with(doc.to_json, hash_including(:quirks_mode => true))
        stub_request(:get, "http://mock/db/test")
          .to_return(:body => doc.to_json)
        mock_conn.get("db/test", :quirks_mode => true)
      end

      context 'when decode_json_objects is true' do
        class TestObject
          def self.json_create(args)
            new
          end
        end

        before(:all) do
          CouchRest.decode_json_objects = true
          CouchRest.put "#{COUCHHOST}/#{TESTDB}/test", JSON.create_id => TestObject.to_s
        end

        after(:all) do
          CouchRest.decode_json_objects = false
        end

        it 'should return the response as a Ruby object' do
          conn = CouchRest::Connection.new(URI(COUCHHOST))
          expect(conn.get("#{TESTDB}/test").class).to eql(TestObject)
        end
      end

      context 'when decode_json_objects is false (the default)' do
        class TestObject2
          def self.json_create(args)
            new
          end
        end

        before(:all) do
          CouchRest.decode_json_objects = false
          CouchRest.put "#{COUCHHOST}/#{TESTDB}/test2", JSON.create_id => TestObject.to_s
        end

        it 'should not return the response as a Ruby object' do
          conn = CouchRest::Connection.new(URI(COUCHHOST))
          expect(conn.get("#{TESTDB}/test2").class).to eql(Hash)
        end
      end
    end

    describe :put do

      let :put_doc do
        { '_id' => 'test-put-doc', 'name' => 'test put document' }
      end

      it "should put a document to the database" do
        conn.put("#{TESTDB}/test-put-doc", put_doc)
        res = conn.get("#{TESTDB}/test-put-doc")
        expect(res['name']).to eql put_doc['name']
        expect(res['_rev']).to_not be_nil
      end

      it "should convert hash into json data" do
        stub_request(:put, "http://mock/db/test-put")
          .with(:body => put_doc.to_json)
          .to_return(:body => simple_response)
        mock_conn.put("db/test-put", put_doc)
      end

      it "should send raw data" do
        stub_request(:put, "http://mock/db/test-put")
          .with(:body => 'raw')
          .to_return(:body => simple_response)
        mock_conn.put("db/test-put", 'raw', :raw => true)
      end

      it "should handle nil doc" do
        stub_request(:put, "http://mock/db/test-put-nil")
          .with(:body => '')
          .to_return(:body => simple_response)
        mock_conn.put("db/test-put-nil", nil)
      end

      it "should send raw data file and detect file type" do
        f = File.open(FIXTURE_PATH + '/attachments/couchdb.png')
        stub_request(:put, "http://mock/db/test-put-image.png")
          .with(:body => f.read, :headers => { 'Content-Type' => 'image/png' })
          .to_return(:body => simple_response)
        f.rewind
        mock_conn.put("db/test-put-image.png", f)
      end

      it "should send raw tempfile and detect file type" do
        f = Tempfile.new('test.png')
        stub_request(:put, "http://mock/db/test-put-image.png")
          .with(:body => f.read, :headers => { 'Content-Type' => 'image/png' })
          .to_return(:body => simple_response)
        f.rewind
        mock_conn.put("db/test-put-image.png", f)
      end

      it "should use as_couch_json method if available" do
        doc = CouchRest::Document.new(put_doc)
        expect(doc).to receive(:as_couch_json).and_return(put_doc)
        stub_request(:put, "http://mock/db/test-put")
          .to_return(:body => simple_response)
        mock_conn.put('db/test-put', doc)
      end

    end

    describe :post do

      let :post_doc do
        { '_id' => 'test-post-doc', 'name' => 'test post document' }
      end

      it "should put a document to the database" do
        conn.put("#{TESTDB}/test-post-doc", post_doc)
        res = conn.get("#{TESTDB}/test-post-doc")
        expect(res['name']).to eql post_doc['name']
        expect(res['_rev']).to_not be_nil
      end

    end

    describe :delete do
      it "should delete a doc" do
        stub_request(:delete, "http://mock/db/test-delete")
          .to_return(:body => simple_response)
        expect(mock_conn.delete('db/test-delete')).to eql('ok' => true)
      end
    end

    describe :copy do
      it "should copy a doc" do
        stub_request(:copy, "http://mock/db/test-copy")
          .with(:headers => { 'Destination' => "test-copy-dest" })
          .to_return(:body => simple_response)
        expect(mock_conn.copy('db/test-copy', 'test-copy-dest')).to eql('ok' => true)
      end
    end

    describe :head do
      it "should send head request" do
        stub_request(:head, "http://mock/db/test-head")
          .to_return(:body => "")
        expect { mock_conn.head('db/test-head') }.to_not raise_error
      end
      it "should handle head request when document missing" do
        stub_request(:head, "http://mock/db/test-missing-head")
          .to_return(:status => 404)
        expect { mock_conn.head('db/test-missing-head') }.to raise_error(CouchRest::NotFound)
      end
    end

  end

  describe :close do

    let :uri do
      URI(DB.to_s + "/test-doc")
    end
    let :conn do
      CouchRest::Connection.new(uri)
    end

    it "should send a shutdown and end the session" do
      conn.get(TESTDB)
      expect(conn.http).to receive(:shutdown)
      conn.close
    end

  end

end