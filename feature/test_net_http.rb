# -*- encoding: utf-8 -*-
require 'test/unit'
require 'net/http'
require File.expand_path('./test_setting', File.dirname(__FILE__))
require File.expand_path('./httpserver', File.dirname(__FILE__))


class TestNetHTTP < Test::Unit::TestCase
  def setup
    @server = HTTPServer.new($host, $port)
    url = URI.parse($url)
    proxy = URI.parse($proxy) if $proxy
    if proxy
      @client = Net::HTTP::Proxy(proxy.host, proxy.port, proxy.user, proxy.password).new(url.host, url.port)
    else
      @client = Net::HTTP.new(url.host, url.port)
    end
    @client.set_debug_output(STDERR) if $DEBUG
    @url = $url
  end

  def teardown
    @server.shutdown
  end

  def test_gzip_get
    assert_equal('hello', @client.get(@url + 'compressed?enc=gzip').body)
    assert_equal('hello', @client.get(@url + 'compressed?enc=deflate').body)
  end

  def test_gzip_post
    assert_equal('hello', @client.post(@url + 'compressed', 'enc=gzip').body)
    assert_equal('hello', @client.post(@url + 'compressed', 'enc=deflate').body)
  end

  def test_put
    assert_equal("put", @client.put(@url + 'servlet', '').body)
    res = @client.put(@url + 'servlet', '1=2&3=4')
    assert_equal('1=2&3=4', res.header["x-query"])
    # bytesize
    res = @client.put(@url + 'servlet', 'txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A')
    assert_equal('txt=%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A', res.header["x-query"])
    assert_equal('15', res.header["x-size"])
  end

  def test_delete
    assert_equal("delete", @client.delete(@url + 'servlet').body)
  end

  def test_post_multipart
    File.open(__FILE__) do |file|
      req = Net::HTTP::Post.new(@url + 'servlet')
      req.set_form({'upload' => file}, 'multipart/form-data')
      res = @client.request(req)
      content = res.body
      assert_match(/FIND_TAG_IN_THIS_FILE/, content)
    end
  end

  def test_basic_auth
    req = Net::HTTP::Get.new(@url + 'basic_auth')
    req.basic_auth('admin', 'admin')
    assert_equal('basic_auth OK', @client.request(req).body)
  end

  def test_digest_auth
    flunk 'digest auth not supported'
    flunk 'digest-sess auth not supported'
  end

  def test_redirect
    assert_equal('hello', @client.get(@url + 'redirect3'))
  end

  def test_redirect_loop_detection
    assert_raise(RuntimeError) do
      @client.get(@url + 'redirect_self')
    end
  end

  def test_keepalive
    server = HTTPServer::KeepAliveServer.new($host)
    url = URI.parse(server.url)
    c = Net::HTTP.new(url.host, url.port)
    c.start
    begin
      5.times do
        assert_equal('12345', c.get(url.path).body)
      end
    ensure
      c.finish
      server.close
    end
    # chunked
    server = HTTPServer::KeepAliveServer.new($host)
    url = URI.parse(server.url)
    c = Net::HTTP.new(url.host, url.port)
    c.start
    begin
      5.times do
        assert_equal('abcdefghijklmnopqrstuvwxyz1234567890abcdef', c.get(url.path + 'chunked').body)
      end
    ensure
      c.finish
      server.close
    end
  end
end

