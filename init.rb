require 'dotenv'
require 'rubygems'
require 'bundler/setup'
require 'zendesk_api'
require 'pry'
require 'mysql2'
require 'ruby-progressbar'
require 'timecop'
require 'aws-sdk'
require 'faker'
require 'pg'
Dotenv.load

uri = URI.parse(ENV['CLEARDB_DATABASE_URL'])

DB = Mysql2::Client.new(:host => uri.host, :username => uri.user, :password => uri.password,:database => uri.path[1..-1])

pg_uri = URI.parse(ENV['DATABASE_URL'])
PG_DB = PG.connect(pg_uri.hostname, pg_uri.port, nil, nil, pg_uri.path[1..-1], pg_uri.user, pg_uri.password)


binding.pry
def connectToZendesk(desk)

  client = ZendeskAPI::Client.new do |config|
    config.url = "https://#{desk["domain"]}/api/v2" # e.g. https://mydesk.zendesk.com/api/v2
    config.username = desk["user"]
    config.token = desk["token"]
    config.retry = false
  end

  client.insert_callback do |env|
    if env[:status] == 429
      DB.query("UPDATE `desks` SET `wait_till` = '#{(env[:response_headers][:retry_after] || 10).to_i + Time.now.to_i}' WHERE `domain` = '#{desk["domain"]}';")
    end
  end

  return client

end

def createTestTic(desk)
  client = connectToZendesk(desk)

  client.tickets.create!(:subject => Faker::Lorem.word, :comment => { :value => Faker::Lorem.sentence }, :submitter_id => client.current_user.id, :priority => "urgent")
end

def createTableIfNeeded(domain)

  uri = URI.parse(ENV['CLEARDB_DATABASE_URL'])

  tables = DB.query("SHOW TABLES FROM #{uri.path[1..-1]}", :as => :array);
  tbls =[]

  tables.each do |table|
    tbls << table[0]
  end

  if !tbls.include? domain
    DB.query("CREATE TABLE `#{domain}` (id BIGINT(16) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT);")
  end
end
