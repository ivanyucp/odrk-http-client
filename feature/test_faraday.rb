# -*- encoding: utf-8 -*-
require 'test/unit'
require 'faraday'
require File.expand_path('./test_setting', File.dirname(__FILE__))
require File.expand_path('./httpserver', File.dirname(__FILE__))


class TestFaraday < Test::Unit::TestCase
  def setup
    @server = HTTPServer.new($host, $port)
    url = URI.parse($url)
    @client = Faraday.new(:url => (url + "/").to_s) { |builder|
      builder.adapter :typhoeus
    }
    @url = url.path
  end

  def teardown
    @server.shutdown
  end

  def test_gzip_get
    flunk('compression not supported')
    assert_equal('hello', @client.get(@url + 'compressed?enc=gzip').body)
    assert_equal('hello', @client.get(@url + 'compressed?enc=deflate').body)
  end

  def test_gzip_post
    flunk('compression not supported')
    assert_equal('hello', @client.post(@url + 'compressed', :enc => 'gzip').body)
    assert_equal('hello', @client.post(@url + 'compressed', :enc => 'deflate').body)
  end

  def test_put
    assert_equal("put", @client.put(@url + 'servlet').body)
    res = @client.put(@url + 'servlet', {1=>2, 3=>4})
    assert_equal('1=2&3=4', res.headers["x-query"])
    # bytesize
    res = @client.put(@url + 'servlet', 'txt' => 'あいうえお')
    assert_equal('txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A', res.headers["x-query"])
    assert_equal('15', res.headers["x-size"])
  end

  def test_delete
    assert_equal("delete", @client.delete(@url + 'servlet').body)
  end

  def test_cookies
    flunk('Cookie not supported')
    res = @client.get(@url + 'cookies', :header => {'Cookie' => 'foo=0; bar=1'})
    assert_equal(2, res.cookies.size)
    5.times do
      res = @client.get(@url + 'cookies')
    end
    assert_equal(2, res.cookies.size)
    assert_equal('6', res.cookies.find { |c| c.name == 'foo' }.value)
    assert_equal('7', res.cookies.find { |c| c.name == 'bar' }.value)
  end

  def test_post_multipart
    url = URI.parse($url)
    @client = Faraday.new(:url => (url + "/").to_s) { |builder|
      builder.adapter :net_http
    }
    res = @client.post(@url + 'servlet', :upload => Faraday::UploadIO.new(__FILE__, 'text/plain'))
    assert_match(/FIND_TAG_IN_THIS_FILE/, res.body)
  end

  def test_basic_auth
    @client.basic_auth('admin', 'admin')
    assert_equal('basic_auth OK', @client.get(@url + 'basic_auth').body)
  end

  def test_digest_auth
    flunk('digest auth is not supported')
  end

  def test_redirect
    assert_equal('hello', @client.get(@url + 'redirect3').body)
  end

  def test_redirect_loop_detection
    assert_raise(RuntimeError) do
      @client.get(@url + 'redirect_self')
    end
  end

  def test_keepalive
    server = HTTPServer::KeepAliveServer.new($host)
    begin
      5.times do
        assert_equal('12345', @client.get(server.url).body)
      end
    ensure
      server.close
    end
    # chunked
    server = HTTPServer::KeepAliveServer.new($host)
    begin
      5.times do
        assert_equal('abcdefghijklmnopqrstuvwxyz1234567890abcdef', @client.get(server.url + 'chunked').body)
      end
    ensure
      server.close
    end
  end
end
