# Flick Scrape Half Hourly

This is a stopgap script to scrape half hourly daily usage and pricing data from Flick.

## Dependencies
- Written for ruby 2.3.0, but should run on >= 1.9.3
- Firefox
- xvfb if wanting to run headless

## Usage

- `bundle install`
- Open `main.rb`, and change the constants, `EMAIL` and `PASSWORD` to your email and password, if you'd like to use an influxDB configure the constants 'INFLUXDBURL' and 'INFLUXDBNAME'. Otherwise comment out line 106 (inital release). You'll neeed to create the database first on your influDB instance, this script will not create the database.
- By default it will scrape all half hourly data from 1/1/2016. If you dont want this much history on the first run, change line 36 from @lastDataDate = parse_date("01/01/2016") to the date you'd like. If you've joined after 01/01/2016 no need to change anything the script will run to the date you joined.
- The script stores the last successful date so only the first run will take a long time, after that it will only scrape the the days since last run.
- `bundle exec ruby main.rb`


## To run headless
sudo apt-get xvfb
execute script: xvfb-run /home/[username]/.rbenv/shims/ruby /[pathtofile]/main.rb

Run "which ruby" to find the install path if the above doesn't work

You can then setup a cron job using the above code to have the scrape run daily to also give you the most up to date info. Make sure you don't hammer the website scraping. The data is only updated once a day so dont do minute or hourly scrapes as there will be no new data...


Data is outputted as CSV to `flickDailyFormated.csv` and if configured will insert into an influxDB (refer above).

Known Issues:
For some reason the html doesn't always get parsed or downloaded fully resulting in an error. Check error.log to identify days that are skipped. There is no fast or easy way to correct and redownload these yet.
Doesn't yet work as a headless install - currently investgating how to get this working.


Thanks to Andrew Pett. Who wrote the intital code to scrape daily usage data. 
I've built on this to make it work for half hourly usage and pricing data.
https://github.com/aspett/flick_scrape

