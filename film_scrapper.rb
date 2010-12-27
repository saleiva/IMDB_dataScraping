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
require 'progressbar'

class FilmScrapper

  attr_accessor :errors
  attr_reader :environment

  @@base_url = 'http://www.imdb.com/chart/top'

  def self.start(options = {})
    @scraper = self.new(options)
  end

  def initialize(options = {})
    @errors = []
    @scraped = 0
    @environment = options[:env] || 'development'
    begin
      configure
      get_film_list      
    rescue Exception => e
      errors.push(e)
    ensure
      persist_films(@film_list)      
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

    def get_film_list
      @film_list = []
      film_item = {}
      puts '##########################################'
      puts 'IMDB TOP FILMS scraper'
      puts '##########################################'

      puts ''
      puts ''
      puts ''

      puts 'Preparing datasource'
      puts '--------------------'
      pg = ProgressBar.new('Scrapping...', 20)
      begin
        doc = Nokogiri::HTML(open(@@base_url)) { |config| config.noent }
        puts ''
        doc.css('div#main table tr').each do |film|
          matches = /.*[^((\d))]/.match(film.css('td[3]').text)
          film_item['Name'] = matches[0] unless matches.nil?
          matches = /.*\((\d*)\)/.match(film.css('td[3]').text)
          film_item['Year'] = matches[1] unless matches.nil?
          puts film_item['Name']
          puts film_item['Year']
          @film_list.push(film_item.clone)  
#          puts film.css('td[3] font a') unless film.css('td[3] font a').nil?
#          film_item['Link'] = film.css('td[3] font a').first['href']
#          puts film_item['Link']
          
        end
        pg.inc
      rescue Exception => e
        errors.push(e)
        pg.inc
      end
      pg.finish
      puts '------------------------------------------------'
    end

    def init_fusion_tables

      @ft.show_tables.each do |table|
        @ft.drop table.id if table.name.match(/pelisIMDB/)
      end

      @pelis_table = @ft.create_table "pelisIMDB", [
        {:name => "Name",       :type => 'string'},
        {:name => "Year",            :type => 'string'}
      ]
    end
    
    def persist_films(films)
      puts ''
      puts ''

      films.delete_at(0)
      puts '-----------------------------------------'
      puts 'Persisting data into Google Fusion Tables...'
      @pelis_table.insert films if films.present?
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

FilmScrapper.start