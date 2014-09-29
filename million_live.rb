#!/usr/bin/env ruby
# -*- encoding: UTF-8 -*-

require 'rubygems'
require 'mechanize'
require 'logger'
require 'ostruct'

class MillionLive
  attr_reader :agent, :log

  def initialize(&block)
    @agent = Mechanize.new do |agent|
      agent.user_agent_alias = 'iPhone'
    end
    @config = OpenStruct.new({
      cookiepath: './cookies.yaml',
    })
    configure(&block) if block
    loadcookie()
  end

  def configure(&block)
    block.call(@config)
  end

  def log=(logger)
    agent.log = @log = logger
  end

  def get(url, retry_count=0)
    log.debug('get %s' % url) if log
    unless url.start_with?('http://')
      url = 'http://imas.gree-apps.net/app/index.php/'+url
    end
    page = agent.get(url)

    case page.uri.host
    when 'imas.gree-apps.net'
      # 良い
      return page

    when 'apps.gree.net'
      # グリーにログインしていない
      log.info('グリーにログインしていない') if log
      raise 'グリーにログインできない' if retry_count >= 1
      login_gree()
      get(url, retry_count+1)

    when 'pf.gree.jp'
      # ML にログインしていない
      log.info('ミリオンライブにログインしていない') if log
      opensocial_url = page.root.css('#iframe_elem').attr('data-src').value
      agent.get(opensocial_url)

    else
      raise page.uri.to_s
    end
  end

  def login_gree
    log.info('グリーにログインする') if log
    url = 'https://id.gree.net/login/entry?ignore_sso=1'

    # ロギンフォーム
    page = agent.get(url)
    page = page.form_with() {|form|
      form.mail = @config.email
      form.user_password = @config.password
    }.submit()

    # JS で次へ
    # var url = "..."; location.href = url 等と書いてある
    raise page.uri.to_s if page.uri.to_s != 'https://id.gree.net/'
    m = page.body.match(/(["'])(http[^'"]+)\1/)
    raise page.body unless m
    page = agent.get(m[2])

    # ログインできたのでついでにクッキー保存
    savecookie()

    page
  end

  def savecookie
    @config.cookiepath or return
    agent.cookie_jar.save(@config.cookiepath)
  end

  def loadcookie
    @config.cookiepath or return
    File.exist?(@config.cookiepath) or return
    agent.cookie_jar.load(@config.cookiepath)
  end
end

def main
  
end

if __FILE__ == $0
  main
end
