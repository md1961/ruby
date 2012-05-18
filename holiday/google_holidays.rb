#! /bin/env ruby

require 'net/http'
require 'uri'
require 'json'

proxy_address = 'itproxy.japex.co.jp'
proxy_port    = 8080

target_address = 'www.google.com'

date_start  = '2012-01-01'
date_end    = '2012-12-31'
max_results = 50

target_url = '/calendar/feeds/japanese__ja@holiday.calendar.google.com/public/full-noattendees?start-min=%s&start-max=%s&max-results=%s&alt=json-in-script&callback=callbackHoliday' % [date_start, date_end, max_results]

proxy = Net::HTTP::Proxy(proxy_address, proxy_port)

proxy.start(target_address) do |http|
  response = http.get(target_url)
  body = response.body
  body.gsub!(/callbackHoliday\((.*)\);$/, '\1')
  json = JSON.parse(body)
  entries = json['feed']['entry']

  #puts JSON.pretty_generate(entries[0])

  h_holidays = Hash.new
  entries.each do |entry|
    title = entry['title']['$t']
    whens = entry['gd$when']
    date_starts = whens.map { |x| x['startTime'] }
    date_starts.each do |date_start|
      if h_holidays[date_start]
        raise "'#{date_start}' has two entries, '#{h_holidays[date_start]}' and '#{title}'"
      end
      h_holidays[date_start] = title
    end
  end

  h_holidays.keys.sort.each do |date_start|
    puts "%s : %s" % [date_start, h_holidays[date_start]]
  end
end

