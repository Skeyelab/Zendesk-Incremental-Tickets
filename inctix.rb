require 'rubygems'
require 'bundler/setup'
require 'zendesk_api'
require 'pry'
require 'mysql2'
require 'ruby-progressbar'

db = Mysql2::Client.new(:host => "107.170.142.131", :username => "zendeskulator", :password => "pR5Raspu",:database => "zdtix")

desks = db.query("select * from desks limit 1;")

desk = desks.first

domain = desk["domain"]

client = ZendeskAPI::Client.new do |config|

  config.url = "https://#{domain}.zendesk.com/api/v2" # e.g. https://mydesk.zendesk.com/api/v2
  config.username = desk["user"]
  config.token = desk["token"]

  config.retry = true

  # require 'logger'
  # config.logger = Logger.new(STDOUT)

end

tables = db.query("SHOW TABLES FROM zdtix",:as => :array);
tbls =[]

tables.each do |table|
  tbls << table[0]
end

if !tbls.include? domain
  db.query("CREATE TABLE `#{domain}` (id INT(11) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT);
")
end

starttime = desk["last_timestamp"].to_i
#binding.pry
begin

  tix = client.tickets.incremental_export(starttime);
  progressbar = ProgressBar.create(:total => 1000,:format => "%a %e %P% Processed: %c from %C")


  tix.each do |tic|
    results = db.query("SHOW COLUMNS FROM #{domain}");
    cols = []

    results.each do |col|
      #puts col["Field"]
      cols << col["Field"]

    end
    apicols = []
    neededcols = []


    tic.keys.each do |key|
      apicols << key
    end

    neededcols = apicols - cols
    if neededcols.count > 0

      querypairs = []

      neededcols.each do |col|
        if (col.include? "minutes") || (col.include? "id")
          pair = {:field => col, :type => "int(16)"}
          querypairs << pair
        elsif (col.include? "_at") || (col.include? "timestamp")
          pair = {:field => col, :type => "datetime"}
          querypairs << pair
        else
          pair = {:field => col, :type => "text"}
          querypairs << pair
        end
      end

      query = "ALTER TABLE #{domain} ADD ("

      querypairs.each do |pair|
        query = query + pair[:field] + " " + pair[:type]+","
      end
      query = query.chomp(",")

      query = query + ");"

      puts "***ADDING COL***"
      puts query

      db.query(query)

    end



    querypairs = {}
    tic.each do |field|
      querypairs[field[0].to_s] = field[1]
    end
    q1 = "REPLACE INTO #{domain} ("
    q2 = ") VALUES ("
    querypairs.each do |key, value|
      q1 = q1 + key.to_s + ", "
      q2 = q2 + "\"" + db.escape(value.to_s) + "\", "
    end

    q1 = q1.chomp(", ")
    q2 = q2.chomp(", ")

    q2 = q2 + ");"

    # puts q1+q2
    db.query(q1+q2)
    progressbar.increment
  end
  oldstarttime = starttime
  if tix.included
    db.query("UPDATE `desks` SET `last_timestamp` = '#{tix.included['end_time']}' WHERE `domain` = '#{domain}';")
    starttime = tix.included['end_time']
  end
  progressbar.finish
end while ((oldstarttime < starttime) && (oldstarttime < Time.now.to_i))
