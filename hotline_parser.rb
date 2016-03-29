require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'logger'

class HotlineParser
  IMAGES_FOLDER = 'images'

  attr_reader :url, :uri, :page, :queue

  def initialize(url)
    @url = url
    @uri = URI.parse(url)
    @queue = Queue.new
    @page = Nokogiri::HTML(open(url))
  end

  def most_cheapest
    product = products.min{ |a,b| a[:price] <=> b[:price] }
    "Most cheapest - #{product[:name]} - #{product[:price]}"
  end

  def most_expensive
    product = products.max{ |a,b| a[:price] <=> b[:price] }
    "Most expensive - #{product[:name]} - #{product[:price]}"
  end

  def avg_price
    products.reduce(0){ |avg, product| avg += product[:price] } / products.count
  end

  def save_images(thread_count = 10)
    create_dir
    init_queue
    run_downloads(thread_count)
  end

  private

  def run_downloads(thread_count)
    threads = []

    thread_count.times.map do
      threads << Thread.new do
        while !queue.empty? && product = queue.pop
          open(product[:image_url]) do |f|
            File.open(file_path(product), 'wb'){ |file| file.puts(f.read) }
          end
        end
      end
    end

    threads.each(&:join)
  rescue => e
    log "Exception occured while downloading images: #{e}"
  end

  def init_queue
    products.each do |product|
      queue << product unless File.exist?(file_path(product))
    end
  end

  def log(msg)
    logger.info(msg)
  end

  def logger
    @logger ||= Logger.new('parser.log')
  end

  def create_dir
    FileUtils.mkdir_p(IMAGES_FOLDER) unless File.directory?(IMAGES_FOLDER)
  end

  def file_path(product)
    ext = File.extname(product[:image_url])
    "#{IMAGES_FOLDER}/#{product[:file_name]}#{ext}"
  end

  def file_name(name)
    match_data = name.match(/(?<name>[^\s]*) (?<id>.*)/)
    id = match_data[:id].split.map(&:downcase).join('_').gsub(/[\/-]/, '_')
    name = match_data[:name].downcase
    "#{name}-#{id}"
  end

  def format_image_url(url)
    "#{uri.scheme}://#{uri.host}#{url}"
  end

  def products
    @products ||= begin
      product_lis = page.xpath('//ul[contains(@class, "catalog")]//li')
      product_lis.map do |product_li|
        name = product_li.xpath('div[contains(@class, "info")]//div[contains(@class, "ttle")]/a/text()').text.strip
        {
          file_name: file_name(name),
          name:      name,
          image_url: format_image_url(product_li.xpath('div[contains(@class, "img-box")]/a/div/img/@src').to_s),
          price:     product_li.xpath('div[contains(@class, "price")]/span[contains(@class, "orng")]/text()').text.strip.gsub(/[^\d]/, '').to_i
        }
      end
    end
  end
end

hotline_parser = HotlineParser.new('http://hotline.ua/bt/holodilniki/?sort=1')

hotline_parser.save_images
p hotline_parser.most_cheapest
p hotline_parser.most_expensive
p hotline_parser.avg_price
