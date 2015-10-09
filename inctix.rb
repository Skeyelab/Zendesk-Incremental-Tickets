require 'rubygems'
require 'bundler/setup'
require 'zendesk_api'
require 'pry'
require 'mysql2'
require 'ruby-progressbar'
require 'timecop'

db = Mysql2::Client.new(:host => "107.170.142.131", :username => "zendeskulator", :password => "pR5Raspu",:database => "zdtix")

begin
  desks = db.query("select * from desks where last_timestamp <= #{Time.now.to_i-300} and wait_till < #{Time.now.to_i} order by last_timestamp desc;")
  #desk = desks.first
  if desks.count > 0
    desks.each do |desk|
      domain = desk["domain"]
      client = ZendeskAPI::Client.new do |config|

        config.url = "https://#{domain}.zendesk.com/api/v2" # e.g. https://mydesk.zendesk.com/api/v2
        config.username = desk["user"]
        config.token = desk["token"]

        config.retry = false

        # require 'logger'
        # config.logger = Logger.new(STDOUT)

      end


      client.insert_callback do |env|
        if env[:status] == 429

          db.query("UPDATE `desks` SET `wait_till` = '#{(env[:response_headers][:retry_after] || 10).to_i + Time.now.to_i}' WHERE `domain` = '#{domain}';")
          # seconds_left = (env[:response_headers][:retry_after] || 10).to_i
          # @logger.warn "You have been rate limited. Retrying in #{seconds_left} seconds..." if @logger

          # seconds_left.times do |i|
          #   sleep 1
          #   time_left = seconds_left - i
          #   @logger.warn "#{time_left}..." if time_left > 0 && time_left % 5 == 0 && @logger
          # end
        end
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
      begin

        puts "Calling #{domain} from #{Time.at(starttime)}"
        tix = client.tickets.incremental_export(starttime);
        # puts tix.response.status
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
              if (col.include? "req_external_id") || (col.include? "_name")
                pair = {:field => col, :type => "varchar(64)"}
                querypairs << pair
              elsif (col.include? "minutes") || (col.include? "id")
                pair = {:field => col, :type => "int(16)"}
                querypairs << pair
              elsif (tix.included["field_headers"][col]) && (tix.included["field_headers"][col].include? "[int]")
                pair = {:field => col, :type => "int(16)"}
                querypairs << pair
              elsif (col.include? "generated_timestamp")
                pair = {:field => col, :type => "int(16)"}
                querypairs << pair
              elsif (col.include? "_at") || (col.include? "timestamp")
                pair = {:field => col, :type => "datetime"}
                querypairs << pair
              elsif col.include? "current_tags"
                pair = {:field => col, :type => "varchar(1024)"}
                querypairs << pair
              else
                pair = {:field => col, :type => "VARCHAR(255)"}
                querypairs << pair
              end
            end

            query = "ALTER TABLE #{domain} ADD ("

            querypairs.each do |pair|
              query = query + pair[:field] + " " + pair[:type]+","
            end
            query = query.chomp(",")

            query = query + ");"

            progressbar.log "***ADDING COL***"
            progressbar.log query

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
          #  binding.pry
          db.query("UPDATE `desks` SET `last_timestamp` = '#{tix.included['end_time']}' WHERE `domain` = '#{domain}';")
          starttime = tix.included['end_time']
        end
        progressbar.finish
      end while ((oldstarttime < starttime) && (oldstarttime < Time.now.to_i))
    end
  else
    sleepinc = db.query("select min(wait_till) from desks;").first["min(wait_till)"] - Time.now.to_i

    if sleepinc > 0
      sleep sleepinc
    end


  end
end while 1
