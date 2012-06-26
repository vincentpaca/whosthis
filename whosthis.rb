require 'nokogiri'
require 'open-uri'
require 'uri'
require 'thread'
require 'whois'

class WhosThis

  def initialize()
    puts "Input the tags to search for separated in spaces : "
    @tags = gets.chomp
    puts "How many results would you like? Give a number : "
    @pages = gets.chomp
  end
  
  def start
    puts "Starting"
    parse("http://www.google.com/search?num=#{@pages}&q=#{@tags.gsub(' ', '+')}")
    puts "Done"
    print "Press any key to exit"
    exit if gets.chomp
  end

  def parse(url)
    result = Nokogiri::HTML(open(url))
    whois = Whois::Client.new
    r = Regexp.new(/\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/)
    File.open("output.txt", 'w') do |f|
      result.css('h3 a').each do |link|
        begin
          host = URI.parse(link['href'].clean).host
          who = whois.query(host.gsub('www.', '')).to_s
          emails = who.scan(r).uniq
          emails.each { |email| f.puts email }
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
a.start
