#!/usr/bin/env ruby
# -*- encoding: UTF-8 -*-

require 'bundler'
Bundler.require
require './million_live'

def main
  $logger = Logger.new(STDOUT)
  $logger.level = Logger::INFO

  $ml = MillionLive.new do |config|
    config.email = ENV['GREE_EMAIL']
    config.password = ENV['GREE_PASSWORD']
    config.cookiepath = nil
  end
  $ml.log = $logger

  $redis = Redis.new(url: ENV['REDISTOGO_URL'] || ENV['REDISCLOUD_URL'])

  $tw = Twitter::REST::Client.new do |config|
    config.consumer_key = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  loop do
    watch() if [0, 30].include?(Time.now.min)
    sleep(60)
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

  status = (title+"\n"+text)[0,maxlength]+"\n"+url
  $logger.info(status)
  $tw.update(status)
end

if __FILE__ == $0
  main
end
