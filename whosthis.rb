require 'nokogiri'
require 'open-uri'
require 'uri'
require 'whois'
require 'anemone'

class WhosThis
  
  @@filtered_mails = ['domaindiscreet', 'domainsbyproxy', 'whois', 'domains']
  @@regex = Regexp.new(/\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/)
  
  def initialize
    #get inputs
    puts "Input the tags to search for separated in spaces : "
    @tags = gets.chomp
    puts "How many results would you like? Give a number : "
    @pages = gets.chomp

    #init whois
    @whois = Whois::Client.new
  end
  
  def start
    puts "Starting"
    parse("http://www.google.com/search?num=#{@pages}&q=#{@tags.gsub(' ', '+')}")
    puts "Done"
  end

  def parse(url)
    result = Nokogiri::HTML(open(url))
    sites = []
    
    File.open("output.txt", 'w') do |f|
      result.css('h3 a').each do |link|
        begin
          host = URI.parse(link['href'].clean).host
          sites << host
          who = @whois.query(host.gsub('www.', '')).to_s
          
          puts "Checking WhoIs for #{host}"
          emails = who.scan(@@regex).uniq
          emails.delete_if { |email| @@filtered_mails.each { |f| email.include?(f) } }
          emails.each { |email| f.puts "WhoIs: #{email} - #{host}" }
          
          if emails.empty?
            begin
              Anemone.crawl("http://#{host}") do |website|
                checked_urls = []
                website.on_pages_like(/(about|info|contact)/) do |page|
                  unless checked_urls.include?(page.url)
                    puts "Checking #{page.url}..."
                    checked_urls << page.url
                    emails = "#{page.doc.at('body')}".scan(@@regex).uniq
                    emails.each { |email| f.puts "Contact page: #{email} - #{host}" } unless emails.nil?
                    break if checked_urls.count > 5
                  else
                    puts "Skipping #{page.url}..."
                  end
                end
              end
            rescue Timeout::Error
              nil
            end
          end
        rescue
          nil
        end
      end
    end
  end

end

class String
  def clean
    str = self.gsub('/url?q=', '')
  end
end

a = WhosThis.new
begin
 a.start
rescue Exception =>e
  File.open("err.txt", 'w') do |f|
    f.puts e.inspect
    f.puts e.backtrace
  end
end
