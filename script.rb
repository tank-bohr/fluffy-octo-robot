#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ruby-progressbar'
require 'mechanize'
require 'net/http'
require 'net/https'
require 'json'
require 'pry'

PAGE_URL = 'https://book-audio.com/find'.freeze
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) " \
    "AppleWebKit/537.36 (KHTML, like Gecko) " \
    "Chrome/57.0.2987.133 Safari/537.36".freeze

PARAMS = {
  sort: :downloads,
  order: :desc,
  excludeRead: 0,
  withAudio: 0,
  duration: :any,
  search: ''.freeze,
  extendedList: :find,
}.freeze

PAGES_COUNT = 1072
NESTED_PARAMS = %w(audioAuthor bookAuthor genre).freeze

def fetch(params)
  uri = URI('https://book-audio.com/find/allcards'.freeze)
  uri.query = URI.encode_www_form(params)
  request = Net::HTTP::Get.new(uri)
  request['User-Agent'.freeze] = USER_AGENT
  request['X-Requested-With'.freeze] = 'XMLHttpRequest'.freeze
  result = Net::HTTP.start(uri.hostname, uri.port, use_ssl: 'https'.freeze == uri.scheme) do |http|
    http.request(request)
  end
  JSON.parse(result.body)
end

def flatten(data)
  data['cards'.freeze].map do |card|
    NESTED_PARAMS.each_with_object(card) do |nested_param, result|
      result[nested_param] = result[nested_param].join(', '.freeze) if result[nested_param]
    end
  end
end

agent = Mechanize.new { |a| a.user_agent = USER_AGENT }

page = agent.get(PAGE_URL)
scripts = page.xpath('//script[not(@*)]')
md = Enumerator.new do |matches|
  scripts.each { |node| matches << node.text.match(/window.CSRF\s=\s\'(?<csrf>[\d\w]+)\'\;/) }
end.detect { |md| !md.nil? }
csrf = md[:csrf]

base_params = PARAMS.merge(CSRF: csrf)
output = File.open('output.json', 'w')
progress_bar = ProgressBar.create(total: PAGES_COUNT, title: "I'm working...")

(1..PAGES_COUNT).each do |page|
  params = base_params.merge(page: page)
  data = fetch(params)
  cards = flatten(data)
  cards.each { |card| output.puts(JSON.dump(card)) }
  progress_bar.increment
end

output.close

puts 'Done!'
