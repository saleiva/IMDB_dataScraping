# encoding: UTF-8

require "rubygems"
require "bundler/setup"

# require your gems as usual
require 'active_support/core_ext/object'
require 'fusion_tables'
require 'launchy'
require 'nokogiri'
require 'open-uri'
require 'ostruct'

class FilmPerYearScrapper

  attr_accessor :errors
  attr_reader :environment
  
  @@base_url = 'http://www.imdb.com/search/title?year='

  def self.start(options = {})
    @scraper = self.new(options)
  end

  def initialize(options = {})
    @errors = []
    @environment = options[:env] || 'development'
    begin
      configure
      get_filmvsyears_n      
    rescue Exception => e
      errors.push(e)
    ensure
      persist_years(@filmvsyears_list)      
      summary
    end
  end

  private
    def configure
      ft_config = OpenStruct.new(YAML.load_file(File.join(File.dirname(__FILE__), "fusion_tables.yml")))
      @ft = GData::Client::FusionTables.new
      @ft.clientlogin(ft_config.user, ft_config.pass)
      init_fusion_tables
    end

    def get_filmvsyears_n
      @filmvsyears_list = []
      year_item = {}
      puts '##########################################'
      puts 'IMDB FILMS PER YEAR scraper'
      puts '##########################################'

      puts ''
      puts ''

      begin
        year = 1920
        while year <= 2010 do
          doc = Nokogiri::HTML(open(@@base_url+year.to_s()+","+year.to_s()+"&title_type=feature&sort=moviemeter,asc")) { |config| config.noent }
          puts ''
          year_item['Year'] = year.to_s()
          number = doc.css('div#left').text
          matches = /\d+\,\d+/.match(number)
          year_item['Number'] = matches[0]
          puts year_item['Year']
          puts year_item['Number']
          @filmvsyears_list.push(year_item.clone)
          year += 1
        end
      rescue Exception => e
        errors.push(e)
      end
      puts '------------------------------------------------'
    end

    def init_fusion_tables

      @ft.show_tables.each do |table|
        @ft.drop table.id if table.name.match(/pelis_vs_years_IMDB/)
      end

      @years_table = @ft.create_table "pelis_vs_years_IMDB", [
        {:name => "Year",       :type => 'string'},
        {:name => "Number",            :type => 'string'}
      ]
    end
    
    def persist_years(years)
      puts ''
      puts ''
      puts '-----------------------------------------'
      puts 'Persisting data into Google Fusion Tables...'
      @years_table.insert years if years.present?
      puts 'Done!'
      puts '-----------------------------------------'

    end    
    
    def summary
      puts '#################################################'
      unless errors.blank?
        puts 'Registered errors:'
        errors.each do |error|
          puts '------------------'
          puts "Error message: #{error.message}"
          puts "backtrace: #{error.backtrace.join("\n")}"
        end
        puts '#################################################'
      end
    end

end

FilmPerYearScrapper.start