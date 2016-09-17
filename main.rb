# coding: utf-8
require "rubygems"
require "selenium-webdriver"
require "csv"
require "nokogiri"

class FlickScrape
  EMAIL = ""
  PASSWORD = ""
  INFLUXDBURL = "http://192.168.2.238:8086"
  INFLUXDBNAME = "FlickUsage"

  def initialize
    @data_array = []
  end

  def main

    #remove old files with daily data
    if File.exist?("flickDaily.csv")
       File.delete("flickDaily.csv")
    end

    if File.exist?("flickDailyFormated.csv")
       File.delete("flickDailyFormated.csv")
    end

    #check date of last data stored
    if File.exist?("mostRecentDataDate.txt")
       File.foreach("mostRecentDataDate.txt") do |line|
          @lastDataDate = parse_date(line)
       end
    else
		#date file doesn't exist so run for all 2016
		#change this if you want to run for more than 2016..
		@lastDataDate = parse_date("01/01/2016")
    end

    @dateChecker = Date.parse("01/01/2016")

    @driver = Selenium::WebDriver.for :firefox
    @driver.navigate.to "http://myflick.flickelectric.co.nz/dashboard/day"

    login

    add_data

    #before adding more data check if already have older data 
	while back_button  
	    daysBetween = (@mostRecentDataDate - @lastDataDate).to_i
	    if  @lastDataDate < @mostRecentDataDate then
		  back_button.click
		  add_data
	    else
  		  break
	    end
	end

    #clean up the csv file that has been created    
    cleanCSV

  ensure
    @driver.quit
  end


  def cleanCSV 
     
     #may not be a file to process if most recent data already been processed
     if File.exist?("flickDaily.csv")
        #start daily data csv file with headings
        CSV.open("flickDailyFormated.csv", "a+") do |csv|
			csv << ["unixTime", "cost", "kWh" ]
        end

        CSV.foreach('flickDaily.csv') do |row|
		tempRow = row.inspect
	
		if tempRow["How much electricity I used"]
	 	   #skip the header rows	  	  
		else
		  rowText = tempRow
		  rowText = rowText.gsub('\n', '').squeeze('')
		  rowText = rowText.gsub(/\s+/, ' ')
		  removeText = rowText.slice(7...16)
		  rowText = rowText.gsub(removeText,'')
		  dateTimeString = rowText.slice(2..16)
		  dateTimeString = parse_date(dateTimeString)

		  unixTimestamp = Time.parse(dateTimeString.strftime('%Y-%m-%d %H:%M:%S:%Z'))

		  CSV.open("flickDailyFormated.csv", "a+") do |csv|
			timestamp = unixTimestamp.strftime('%s')
			cost =row[1].gsub('¢', '')
			usage = row[2].gsub(' units', '')
		     csv << [unixTimestamp, cost,usage]
		     puts `curl -i -XPOST '#{INFLUXDBURL}/write?db=#{INFLUXDBNAME}&precision=s' --data-binary 'powerUsage,location=home cost=#{cost},kWh=#{usage} #{timestamp}' `
		  end
	    end	
     end
    end
  end


  def login
    @driver.find_element(:name, 'user[email]').send_keys(EMAIL)
    password = @driver.find_element(:name, 'user[password]')
    password.send_keys(PASSWORD)
    password.submit
  end

  def add_data

    @html = @driver.page_source
    document = Nokogiri::HTML(@html)
    File.write('latestPage.html', document)

    #find current date to test if already stored/extracted - somes times fails for unknown reason...
    begin
    	@mostRecentDataDate = parse_date(document.at_css('//span[@id="date-navigation-calendar"]').text.strip)
    rescue 
		puts "Error processing the date after: " + @mostRecentDataDate.strftime("%Y-%m-%d")
		#no html to process so just go to next date
		errorLog = File.open("error.log", "a")
		errorLog.puts Time.now.strftime("%d/%m/%Y %H:%M") + "  Error processing the date after: " + @mostRecentDataDate.strftime("%Y-%m-%d") + " continuing to older dates"
		return
    end

    #check if latest data is available yet i.e. if usage is "Unavailable" stop
    checkUnavailable = ""
    begin 
    	checkUnavailable = document.at('td:contains("Unavailable")').text.strip
    rescue 
		checkUnavailable = "Data available continue extracting"	
    end

    if (checkUnavailable == "Unavailable")
		errorLog = File.open("error.log", "a")
		errorLog.puts Time.now.strftime("%d/%m/%Y %H:%M") + "  Usage data Unavailable for: " + @mostRecentDataDate.strftime("%Y-%m-%d") + " continuing to older dates"
		puts "usage data Unavailable for: " + @mostRecentDataDate.strftime("%Y-%m-%d") + " continuing to older dates"
		return
    end
    
    if (@mostRecentDataDate == @lastDataDate)
		puts "Most recent data has already been downloaded, stop processing"
		return
    end

    if (@mostRecentDataDate > @dateChecker)
		@dateChecker = @mostRecentDataDate
		puts "Newer date found, saving new date to txt file"
		File.write('mostRecentDataDate.txt', @mostRecentDataDate)
    end
    
    #test if most recent date is older if older process and save
	if (@mostRecentDataDate - @lastDataDate).to_i > 0
	    puts "New data to process"
	    document.at('table').search('tr').each do |row|
		cells = row.search('th, td').map { |cell| cell.text.strip }
		out_csv = File.open("flickDaily.csv", "a")
		out_csv.puts(CSV.generate_line(cells))
		out_csv.close
	    end
	end
  end

  def back_button
    @driver.find_element(:xpath, "//span[@class='date-navigation']/a[text()='◀']") rescue nil
  end

  def parse_date(date)
    DateTime.parse(date) rescue nil
  end

end

FlickScrape.new.main
