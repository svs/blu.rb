require 'rubygems'
require 'sinatra'
require 'RedCloth'
require 'haml'
require 'cgi'
require 'rss/maker'
require 'chronic'


def entries
  @posts = {}
  Dir.entries("./views/posts/").reject{|f| f.match(/~$/)}.each_with_index do |post, i|
    File.open("views/posts/#{post}") do |file|
      # read the first line of the file and check if its a date unless it's a directory
      date = Chronic.parse(file.gets) unless File::directory?("views/posts/#{post}")
      @posts[date] = post if date
    end
  end
  @posts
end

get "/" do
  RedCloth.new(haml :blog_index).to_html
end

get "/blog/:title" do
  _title = params[:title].split(".")
  if ["haml","erb"].include?(_title[-1])
    @title = _title[0]
    layout = File.read("views/posts/layouts/_#{t[1]}.haml") if _title.size == 3
    haml ":plain\n\t" + RedCloth.new(File.read("views/posts/#{params[:title]}")).to_html, :layout => layout
  else
    @title = params[:title]
    File.read("views/posts/#{params[:title]}")
  end
end

get "/blog" do
  haml :blog_index
end

get "/feed" do
  #TODO recreate only on git post commit hook
  File.read("feed.xml")
end

def write_feed(request)
  version = "2.0" # ["0.9", "1.0", "2.0"]
  destination = "test_maker.xml" # local file to write

  content = RSS::Maker.make(version) do |m|
    m.channel.title = "prole.in"
    m.channel.link = "http://prole.in/blog"
    m.channel.description = "What the prole has been writing"
    m.items.do_sort = true # sort items by date

    entries.each do |atime,entry|
      i = m.items.new_item
      i.title = entry
      port = request.env["SERVER_PORT"]
      host_root = "http://#{request.env["SERVER_NAME"]}" + (port == "80" ? "" : ":#{port}")
      i.link = host_root + "/blog/#{CGI::escape(entry)}"
      i.description = haml ":plain\n\t" + RedCloth.new(File.read("views/posts/#{params[:title]}")).to_html, :layout => layout
      i.date = atime
    end
  end
  File.open("feed.xml","w"){|f| f.write(content.to_xml)}
end

def update_blog(request)
  `cd views/posts;git pull`
  write_feed(request)
  `touch tmp/restart.txt`
  "blog updated"
end

get '/update_blog' do #manual update
  update_blog(request)
end

post '/update_blog' do # for github post-commit hook
  update_blog(request)
end

get "/:page" do
  haml RedCloth.new(File.read("views/#{params[:page]}")).to_html
end


helpers do
  def image_tag(filename, options={})
    unless options.empty?
      attrs = []
      attrs = options.map { |key, value| %(#{key}="#{Rack::Utils.escape_html(value)}") }
      @options = " #{attrs.sort * ' '}" unless attrs.empty?
    end
    "<img src='/images/#{filename}' #{@options}/>"
  end
end

class Date
  def inspect
    strftime "%m %d %Y"
  end
end
