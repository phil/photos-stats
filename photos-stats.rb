#! /usr/bin/env ruby

# Bundle inline to avoid users having to install gems
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem "activesupport"
  gem "thor"
  gem "sqlite3"
end

require 'json'

module PhotosStats

  class CLI < Thor

    desc "overview", "Show an overview of your photos library"
    def overview
      puts "Total assets: #{connection.execute("SELECT count(*) FROM zasset").first.first}"
    end

    desc "stats", "Show stats about your photos library"
    #method_options tables: :array
    def stats
      tables.each do |table|
        puts "===================="
        puts "#{table}"
        puts "===================="
        connection.execute("SELECT #{table}, count(*) FROM zextendedattributes GROUP BY #{table} ORDER BY #{table} ASC").each do |row|
          puts "#{row[0] || "null"}, #{row[1]}"
        end
        puts ""
      end
    end

    desc "export", "Export stats about your photos library as JSON"
    def export

      data = {
        total_photos: 0,
        first_photo: nil,
        last_photo: nil,

        photos_per_month: {},
        
        cameras: [],
        makes: [],
        lenses: [],
      }

      connection.execute(<<-SQL).each do |row|
select zcameramodel, zcameramake, datetime(min(zasset.ZDATECREATED), 'auto', '+31 years'), datetime(max(zasset.ZDATECREATED), 'auto', '+31 years'), count(*), group_concat(ZLENSMODEL) 
from zextendedattributes 
join zasset on zextendedattributes.ZASSET = zasset.z_pk
WHERE ZASSET.ZTRASHEDDATE IS NULL
group by zcameramodel order by zcameramodel ASC;
SQL

        data[:cameras] << { name: row[0], make: row[1], first: row[2], last: row[3], count: row[4], lenses: row[5] && row[5].split(",").sort.uniq }
      end

      puts JSON.dump(data)

    end

    private

    def photos_library_path
      File.join(__dir__, "Photos.sqlite")
    end

    def connection
      @connection ||= SQLite3::Database.new photos_library_path
    end

    def tables
      options[:tables] || %w(zcameramodel zcameramake zlensmodel zfocallength ziso zaperture zshutterspeed)
    end
  end
end

# select zcameramodel as camera, count(*) as c from zextendedattributes group by zcameramodel order by camera ASC
# select zcameramake as make, count(*) as c from zextendedattributes group by zcameramake order by make ASC
# select zlensmodel as lens, count(*) as c from zextendedattributes group by zlensmodel order by lens ASC
# select zfocallength as focallength, count(*) as c from zextendedattributes group by zfocallength order by focallength ASC
# select ziso as iso, count(*) as c from zextendedattributes group by ziso order by iso ASC

PhotosStats::CLI.start
