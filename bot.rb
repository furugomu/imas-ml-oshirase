#!/usr/bin/env ruby
# -*- encoding: UTF-8 -*-

require 'bundler'
Bundler.require
require './million_live'

def main
  $ml = MillionLive.new do |config|
    config.email = ENV['GREE_EMAIL']
    config.password = ENV['GREE_PASSWORD']
    config.cookiepath = nil
  end

  $redis = Redis.new(url: ENV['REDISTOGO_URL'] || ENV['REDISCLOUD_URL'])

  $tw = Twitter::REST::Client.new do |config|
    config.consumer_key = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  loop do
    watch()
    sleep(5*60)
  end
end

def watch()
  page = $ml.get('toppage/information_list')
  links = page.links_with(href: %r(/information/id/))
  # おしらせリンクを探す
  links.reverse.each do |link|
    title = link.text.gsub(/\s+/, ' ').strip()
    url = link.href
    # 新しいかタイトルが変わっていたらつぶやく
    old_title = $redis.get(url)
    puts 'url: %s, title: %s, old_title: %s' % [url, title, old_title]
    next if old_title == title
    $redis.set(url, title)
    tweet(url, title)
  end
end

def tweet(url, title)
  # TODO https://dev.twitter.com/rest/reference/get/help/configuration
  url_length = 23
  maxlength = 140 - url_length - 1

  # おしらせ本文
  page = $ml.get(url)
  element = page.root.at('.list-bg')
  text = element ? element.text.dup : ''
  text.sub!('「アイドルマスター ミリオンライブ！」をご利用いただき、誠にありがとうございます。', '')
  text.strip!

  $tw.update((title+"\n"+text)[0,maxlength]+"\n"+url)
end

if __FILE__ == $0
  main
end
