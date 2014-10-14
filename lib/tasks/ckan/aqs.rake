namespace :ckan do 

  namespace :airnow do

    task :update do 
      Rake.application.invoke_task("ckan:airnow:sites:check_resource_exists_and_upsert")
      Rake.application.invoke_task("ckan:airnow:data:check_resource_exists_and_upsert")
    end

    namespace :sites do

      desc "Create CKAN resource for AQS monitoring sites (if it doesn't exist) and then upsert CKAN"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_AQS_SITE_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first
        # if there is no resource, create it
        if resource.nil?
          create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create",
            {:resource => {
                :package_id => ENV['CKAN_AQS_DATASET_ID'],
                :name => ENV['CKAN_AQS_SITE_RESOURCE_NAME']
              },
              :primary_key => 'aqs_id',
              :indexes => 'aqs_id,site_name,status,cmsa_name,msa_name,state_name,county_name',
              :fields => [
                {:id => "aqs_id", :type => "text"},
                {:id => "site_code", :type => "text"},
                {:id => "site_name", :type => "text"},
                {:id => "status", :type => "text"},
                {:id => "agency_id", :type => "text"},
                {:id => "agency_name", :type => "text"},
                {:id => "epa_region", :type => "text"},
                {:id => "lat", :type => "float"},
                {:id => "lon", :type => "float"},
                {:id => "elevation", :type => "text"},
                {:id => "gmt_offset", :type => "text"},
                {:id => "country_code", :type => "text"},
                {:id => "cmsa_code", :type => "text"},
                {:id => "cmsa_name", :type => "text"},
                {:id => "msa_code", :type => "text"},
                {:id => "msa_name", :type => "text"},
                {:id => "state_code", :type => "text"},
                {:id => "state_name", :type => "text"},
                {:id => "county_code", :type => "text"},
                {:id => "county_name", :type => "text"},
                {:id => "city_code", :type => "text"},
              ],
              :records => []
            }.to_json,
            {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          create_results = JSON.parse(create_raw)
          resource_id = create_results["result"]["resource_id"]
          # puts "Created a new resource named '#{ENV['CKAN_AQS_SITE_RESOURCE_NAME']}'"
        else
          resource_id = resource["id"]
          # puts "Resource named '#{ENV['CKAN_AQS_SITE_RESOURCE_NAME']}' already existed"
        end
        # puts "Resource ID = #{resource_id}"
        # invoke upsert rake task
        Rake.application.invoke_task("ckan:airnow:sites:upsert[#{resource_id}]")
      end


      desc "Open file that has monitoring site listings from FTP and import into CKAN"
      task :upsert, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?
        raise "AirNow credentials not set (see README)" unless ENV['AIRNOW_USER'] && ENV['AIRNOW_PASS']

        # connect to FTP and load the data into a variable
        ftp = Net::FTP.new('ftp.airnowapi.org')
        ftp.login(ENV['AIRNOW_USER'], ENV['AIRNOW_PASS'])
        ftp.passive = true
        # puts "Opening file from FTP..."
        data = ftp.getbinaryfile('Locations/monitoring_site_locations.dat', nil, 1024)
        ftp.close

        # puts "Parsing sites file and upserting rows..."
        CSV.parse(data, :col_sep => "|", :encoding => 'UTF-8') do |row|
          site_data = {
            :aqs_id => row[0],
            :site_code => row[2],
            :site_name => fix_encoding(row[3]),
            :status => row[4],
            :agency_id => row[5],
            :agency_name => fix_encoding(row[6]),
            :epa_region => row[7],
            :lat => row[8],
            :lon => row[9],
            :elevation => row[10],
            :gmt_offset => row[11],
            :country_code => row[12],
            :cmsa_code => row[13],
            :cmsa_name => row[14],
            :msa_code => row[15],
            :msa_name => row[16],
            :state_code => row[17],
            :state_name => row[18],
            :county_code => row[19],
            :county_name => row[20],
            :city_code => row[21],
          }
          post_data = {:resource_id => args[:resource_id], :records => [site_data], :method => 'upsert'}.to_json
          upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          upsert_result = JSON.parse(upsert_raw)
        end

        # puts "\nAQS Monitoring Sites data upserts complete"
      end
    end


    namespace :data do

      desc "Create CKAN resource for data (if it doesn't exist) and then upsert CKAN"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_AQS_DATA_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first

        create_resource_data = {
          :primary_key => 'id',
          :fields => [
            {:id => "id", :type => "text"},
            {:id => "aqs_id", :type => "text"},
            {:id => "date", :type => "date"},
            {:id => "time", :type => "time"},
            {:id => "parameter", :type => "text"},
            {:id => "unit", :type => "text"},
            {:id => "value", :type => "float"},
            {:id => "data_source", :type => "text"},                
            {:id => "computed_aqi", :type => "int"},                
            {:id => "datetime", :type => "timestamp"},
          ],
          :records => []
        }

        if resource.nil? # if there is no resource, create it inside the right package
          # modify indexes here because we have added custom ones through pgsql 
          create_resource_data[:indexes] = 'id,aqs_id,date,time,parameter,datetime',
          create_resource_data[:resource] = {:package_id => ENV['CKAN_AQS_DATASET_ID'], :name => ENV['CKAN_AQS_DATA_RESOURCE_NAME'] }
        else # update existing resource
          create_resource_data[:resource_id] = resource["id"]
        end
        begin
        create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create", create_resource_data.to_json,
          {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        create_results = JSON.parse(create_raw)
        resource_id = create_results["result"]["resource_id"]
        rescue
          resource_id = resource["id"]
        end
        # puts "Created/updated a new resource named '#{ENV['CKAN_AQS_DATA_RESOURCE_NAME']}' (resource id = #{resource_id}"

        # invoke upsert rake tasks
        Rake.application.invoke_task("ckan:airnow:data:upsert_daily[#{resource_id}]")
        Rake.application.invoke_task("ckan:airnow:data:upsert_hourly[#{resource_id}]")
      end

      desc "Open file that has daily monitoring data from FTP and import into CKAN"
      task :upsert_daily, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?
        raise "AirNow credentials not set (see README)" unless ENV['AIRNOW_USER'] && ENV['AIRNOW_PASS']

        # connect to FTP and load the data into a variable
        ftp = Net::FTP.new('ftp.airnowapi.org')
        ftp.login(ENV['AIRNOW_USER'], ENV['AIRNOW_PASS'])
        ftp.passive = true # for Heroku
        # puts "Opening file from FTP..."
        begin
          data = ftp.getbinaryfile("DailyData/#{TODAY}-peak.dat", nil, 1024)
          ftp.close

          # puts "Parsing daily file and upserting rows..."
          CSV.parse(data, :col_sep => "|", :encoding => 'UTF-8') do |row|
            monitoring_data = {
              :aqs_id => row[1],
              :date => Time.strptime(row[0],'%m/%d/%y').strftime("%Y-%m-%d"),
              :time => nil,
              :parameter => row[3],
              :unit => row[4],
              :value => row[5].to_f,
              :computed_aqi => determine_aqi(row[3], row[5].to_f, row[4]),
              :data_source => fix_encoding(row[7]),
            }
            monitoring_data[:datetime] = monitoring_data[:date]
            monitoring_data[:id] = "#{monitoring_data[:aqs_id]}|#{monitoring_data[:date]}|#{monitoring_data[:time]}|#{monitoring_data[:datetime]}|#{monitoring_data[:parameter]}"
            post_data = {:resource_id => args[:resource_id], :records => [monitoring_data], :method => 'upsert'}.to_json
            upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
            upsert_result = JSON.parse(upsert_raw)
          end
        rescue
          puts "ERROR: rescued from AQS daily file"
        end

        # puts "\nAQS Monitoring daily data upserts complete"
      end

      desc "Open file that has hourly monitoring data from FTP and import into CKAN"
      task :upsert_hourly, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?
        raise "AirNow credentials not set (see README)" unless ENV['AIRNOW_USER'] && ENV['AIRNOW_PASS']

        # connect to FTP and load the data into a variable
        ftp = Net::FTP.new('ftp.airnowapi.org')
        ftp.login(ENV['AIRNOW_USER'], ENV['AIRNOW_PASS'])
        ftp.passive = true # for Heroku

        [TODAY,YESTERDAY].each  do |day|
          HOURS.each do |hour|
            file = "HourlyData/#{day}#{hour}.dat"
            begin
              # puts "Getting #{file}"
              data = ftp.getbinaryfile(file, nil, 1024)
              # puts "Processing #{file}"
              CSV.parse(data, :col_sep => "|", :encoding => 'ISO8859-1') do |row|
                if ["NO2T","NO2","NO2Y","CO","CO-8HR","RHUM","TEMP","PM2.5","WS","WD","PM2.5-24HR","SO2-24HR","SO2","PM10","PM10-24HR"].include?(row[5].upcase)
                  monitoring_data = {
                    :aqs_id => row[2],
                    :date => Time.strptime(row[0],'%m/%d/%y').strftime("%Y-%m-%d"),
                    :time => "#{row[1]}:00",
                    :parameter => row[5].upcase,
                    :unit => row[6],
                    :value => row[7].to_f,
                    :data_source => fix_encoding(row[8]),
                  }
                  monitoring_data[:datetime] = monitoring_data[:date] + " " + monitoring_data[:time]
                  monitoring_data[:id] = "#{monitoring_data[:aqs_id]}|#{monitoring_data[:date]}|#{monitoring_data[:time]}|#{monitoring_data[:parameter]}"
                  post_data = {:resource_id => args[:resource_id], :records => [monitoring_data], :method => 'upsert'}.to_json
                  upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
                  upsert_result = JSON.parse(upsert_raw)
                end
              end
            rescue => e
              puts "ERROR: #{file} -- #{e} / #{e.message}" unless e.message.scan(/No such file or directory/)
            end
          end
        end

        ftp.close

        # puts "\nAQS Monitoring hourly data upserts complete"
      end


    end
  end

end