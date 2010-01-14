require 'rubygems'
require 'sinatra'
require 'RedCloth'
require 'erb'
require 'cgi'
require 'rss/maker'

def entries
  @posts = {}
  ((Dir.entries("./views/posts/").reject{|e| e.match(/~$/)}) - [".","..","layout.erb",".git",".gitignore", "images", "layouts"]).each_with_index do |post, i|
    @posts[File.mtime("views/posts/#{post}") + i] = post
  end
  @posts
end

get "/" do
  erb :index
end

get "/blog/:title" do
  if params[:title].index(".erb")
    t = params[:title].split(".")
    @title = t[0]
    if t.size == 3
      layout = File.read("views/posts/layouts/_#{t[1]}.erb")
    end
    @erb = erb File.read("views/posts/#{params[:title]}"), :layout => layout
    @output = RedCloth.new(@erb).to_html
    @output
  else
    @title = params[:title]
    File.read("views/posts/#{params[:title]}")
  end
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
