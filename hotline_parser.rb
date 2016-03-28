require 'nokogiri'
require 'open-uri'
require 'fileutils'

class HotlineParser
  IMAGES_FOLDER = 'images'.freeze
  private_constant :IMAGES_FOLDER

  attr_reader :url, :uri

  def initialize(url)
    @url = url
    @uri = URI.parse(url)
  end

  def most_cheapest
    product = products.min { |a,b| a[:price] <=> b[:price] }
    "Most cheapest - #{product[:name]} - #{product[:price]}"
  end

  def most_expensive
    product = products.max { |a,b| a[:price] <=> b[:price] }
    "Most expensive - #{product[:name]} - #{product[:price]}"
  end

  def avg_price
    products.reduce(0){ |avg, product| avg += product[:price] } / products.count
  end

  def save_images(thread_count = 4)
    FileUtils.mkdir_p(IMAGES_FOLDER) unless File.directory?(IMAGES_FOLDER)

    queue = Queue.new
    threads = []

    products.each do |product|
      queue << product unless File.exist?(file_path(product))
    end

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
  end

  private

  def file_path(product)
    ext = File.extname(product[:image_url])
    "#{IMAGES_FOLDER}/#{file_name(product)}#{ext}"
  end

  def file_name(product)
    match_data = product[:name].match(/(?<name>[^\s]*) (?<id>.*)/)
    id = match_data[:id].split.map(&:downcase).join('_').gsub(/[\/-]/, '_')
    name = match_data[:name].downcase
    "#{name}-#{id}"
  end

  def format_image_url(url)
    "#{uri.scheme}://#{uri.host}#{url}"
  end

  def page
    @page ||= Nokogiri::HTML(open(url))
  end

  def products
    @products ||= begin
      product_lis = page.css('ul.catalog li')
      product_lis.map do |product_li|
        {
          name:      product_li.css('.info .ttle > a').text().strip,
          image_url: format_image_url(product_li.xpath('*[contains(@class, "img-box")]/a/div/img/@src').to_s),
          price:     product_li.xpath('*[contains(@class, "price")]/span[contains(@class, "orng")]/text()').text.strip.gsub(/[^\d]/, '').to_i
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
