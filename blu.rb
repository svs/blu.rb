require 'rubygems'
require 'sinatra'
require 'RedCloth'
require 'erb'
require 'cgi'
require 'rss/maker'

def entries(dir = "views/posts", ignore = [])
  files = {}
  ignore += [".", ".."]
  ((Dir.entries(dir).reject{|e| e.match(/~$/)}) - ignore).each_with_index do |post, i|
    files[File.ctime("#{dir}/#{post}") + i] = post
  end
  files
end

get "/" do
  erb :index, :layout => :home
end

get "/blog/:title" do
  @title = params[:title].split(".")[0]
  erbt("posts/#{@title}".to_sym, :blog)
end

get "/blog" do
  erb :blog_index
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
      i.description = File.read("views/posts/#{entry}")
      i.date = atime
    end
  end
  File.open("feed.xml","w"){|f| f.write(content.to_xml)}
end

def update_blog(request)
  `cd views/posts;git pull`
  write_feed(request)
  "blog updated"
end

get '/update_blog' do #manual update
  update_blog(request)
end

post '/update_blog' do # for github post-commit hook
  update_blog(request)
end

get '/:page' do
  erbt(params[:page].to_sym, true)
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

  def random_image(dir)
    images = Dir.entries('public/images/site-images') - [".",".."]
    i = images[rand(images.length - 1)]
    "<img src='/images/site-images/#{i}'>"
  end

  def terb(file, layout = false)
    # provides erb after textilizing a file
    erb(RedCloth.new(File.read("views/#{file}"), :layout => layout))
  end

  def erbt(file, layout = true)
    RedCloth.new(erb(file, :layout => layout)).to_html
  end

  def partial(file)
    RedCloth.new(erb(file, :layout => false)).to_html
  end
end
