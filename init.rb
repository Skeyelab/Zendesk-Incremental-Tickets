
require 'dotenv'
require 'rubygems'
require 'bundler/setup'
require 'zendesk_api'
require 'pry'
require 'mysql2'
require 'ruby-progressbar'
require 'timecop'
Dotenv.load

DB = Mysql2::Client.new(:host => ENV['HOST'], :username => ENV['USERNAME'], :password => ENV['PASSWORD'],:database => ENV['DB'])

def connectToZendesk(desk)

  client = ZendeskAPI::Client.new do |config|
    config.url = "https://#{desk["domain"]}/api/v2" # e.g. https://mydesk.zendesk.com/api/v2
    config.username = desk["user"]
    config.token = desk["token"]
    config.retry = false
  end

  client.insert_callback do |env|
    if env[:status] == 429
      db.query("UPDATE `desks` SET `wait_till` = '#{(env[:response_headers][:retry_after] || 10).to_i + Time.now.to_i}' WHERE `domain` = '#{desk["domain"]}';")
    end
  end

  return client

end
