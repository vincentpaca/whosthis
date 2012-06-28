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
    puts "Use a proxy? (Y/N) : "
    @use_proxy = gets.chomp

    #init whois
    @whois = Whois::Client.new
  end
  
  def start
    puts "Starting"
    parse("http://www.google.com/search?num=#{@pages}&q=#{@tags.gsub(' ', '+')}")
    puts "Done"
  end

  def parse(url)
    result = ""
    if @use_proxy.downcase.include?("y")
      puts "Selecting a working proxy server, this will take a while :)"
      proxy = find_working_proxy
      begin
        puts "Searching Google for '#{@tags}'"
        result = Nokogiri::HTML(open(url, :proxy => "http://#{proxy[:host]}:#{proxy[:port]}"))
      rescue
        puts "The server timed out, retrying..."
        retry
      end
    else
      puts "Searching Google for '#{@tags}'"
      result = Nokogiri::HTML(open(url))
    end
    sites = []
    File.open("output.txt", 'w') do |f|
      result.css('h3 a').each do |link|
        begin
          host = URI.parse(link['href'].clean).host
          #somtimes, a website gets two spots on the list. greedy bastards.
          break if sites.include?(host)
          sites << host
          who = @whois.query(host.gsub('www.', '')).to_s
          puts "Checking WhoIs for #{host}"
          emails = who.scan(@@regex).uniq
          #remove emails which we think are 'host-generated' emails
          emails.delete_if { |email| @@filtered_mails.each { |f| email.include?(f) } }
          emails.each { |email| f.puts "WhoIs: #{email} - #{host}" }
          #if can't find anything from WhoIs, dig into their contact/about pages
          if emails.empty?
            begin
              Anemone.crawl("http://#{host}", :proxy_host => proxy[:host], :proxy_port => proxy[:port]) do |website|
                checked_urls = []
                website.on_pages_like(/(about|info|contact)/) do |page|
                  #skip this url if we've been here before
                  break if checked_urls.include?(page.url)
                  puts "Checking #{page.url}..."
                  checked_urls << page.url
                  emails = "#{page.doc.at('body')}".scan(@@regex).uniq
                  emails.each { |email| f.puts "Contact page: #{email} - #{page.url}" } unless emails.nil?
                  #NOBODY HAS 5 CONTACT US PAGES. NOBODY. 
                  break if checked_urls.count > 5
                end
              end
            rescue Timeout::Error
              puts "The server timed out, retrying..."
              retry
            end
          end
        rescue
          nil
        end
      end
    end
  end

  def find_working_proxy
    get_proxies.each do |proxy|
      print "Testing #{proxy[:host]}:#{proxy[:port]}..."
      begin
        result = Nokogiri::HTML(open("http://google.com/search?num=1&q=test", :proxy => "http://#{proxy[:host]}:#{proxy[:port]}"))
        puts "Working!"
        return proxy
      rescue
        puts "Failed!"
      end
    end
  end

  def get_proxies
    uri = URI.parse("http://hidemyass.com/proxy-list/search-226094")
    dom = Nokogiri::HTML(open(uri))

    @proxies ||= dom.xpath('//table[@id="listtable"]/tr').collect do |node|
      if node.at_xpath('td[5]/div').at_xpath('div').to_s.include?("fast") || node.at_xpath('td[6]/div').at_xpath('div').to_s.include?("fast") || node.at_xpath('td[8]').to_s.include?("High")
        { port: node.at_xpath('td[3]').content.strip,
          host: node.at_xpath('td[2]/span').xpath('text() | *[not(contains(@style, "display:none"))]').map(&:content).compact.join.to_s }
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
