#!/usr/bin/env ruby

require_relative 'init'


begin
  qry = "select * from desks where last_timestamp <= #{Time.now.to_i-300} and wait_till < #{Time.now.to_i} and active = 1 order by last_timestamp desc;"
  desks = DB.query(qry)
  if desks.count > 0
    desks.each do |desk|

      client = connectToZendesk(desk)

      createTableIfNeeded(desk["domain"])

      starttime = desk["last_timestamp"].to_i

      begin

        puts "Calling #{desk["domain"]} from #{Time.at(starttime)}"
        tix = client.tickets.incremental_export(starttime);
        progressbar = ProgressBar.create(:total => 1000,:format => "%a %e %P% Processed: %c from %C")

        tix.each do |tic|
          results = DB.query("SHOW COLUMNS FROM `#{desk["domain"]}`");
          cols = []

          results.each do |col|
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

            query = "ALTER TABLE `#{desk["domain"]}` ADD ("

            querypairs.each do |pair|
              query = query + pair[:field] + " " + pair[:type]+","
            end
            query = query.chomp(",")

            query = query + ");"

            progressbar.log "***ADDING COL***"
            progressbar.log query

            DB.query(query)

          end

          querypairs = {}
          tic.each do |field|
            querypairs[field[0].to_s] = field[1]
          end
          q1 = "REPLACE INTO `#{desk["domain"]}` ("
          q2 = ") VALUES ("
          querypairs.each do |key, value|
            q1 = q1 + key.to_s + ", "
            q2 = q2 + "\"" + DB.escape(value.to_s) + "\", "
          end

          q1 = q1.chomp(", ")
          q2 = q2.chomp(", ")
          q2 = q2 + ");"

          DB.query(q1+q2)
          progressbar.increment
        end
        oldstarttime = starttime
        if tix.included
          if tix.included['end_time']
            starttime = tix.included['end_time']
          else
            starttime = 0
          end

          if starttime != 0
            DB.query("UPDATE `desks` SET `last_timestamp` = '#{starttime}' WHERE `domain` = '#{desk["domain"]}';")
          end
        end
        progressbar.finish
      end while ((oldstarttime < starttime) && (oldstarttime < Time.now.to_i))
    end

  else
    sleepinc = (DB.query("select min(wait_till) - UNIX_TIMESTAMP() as sleeptime from desks where active = 1 and `wait_till` >= UNIX_TIMESTAMP()").first["sleeptime"] || 0)
    if sleepinc > 0
      puts "Sleeping #{sleepinc}..."
      sleepinc.times do |i|
        sleep 1
        time_left = sleepinc - i
        puts "Sleeping #{time_left}..." if time_left > 0 && time_left % 5 == 0
      end
    end
  end

end while 1
