require 'rubygems'
require 'sinatra'
require 'RedCloth'
require 'erb'
require 'cgi'
require 'rss/maker'

def entries
  @posts = {}
  (Dir.entries("views/posts/").reject{|p| /[#~]/.match(p) != nil} - [".","..","layout.erb",".git",".gitignore", "images"]).each do |post| 
    @posts[File.atime("views/posts/#{post}")] = post
  end
  @posts
end

get "/" do
  redirect "/index.html"
end

get "/blog/images/:filename" do
  filename = "views/posts/images/#{params[:filename]}"
  raise Sinatra::NotFound unless File.exists?(filename)
  File.read(filename) 
end

get "/blog/:title" do
  if params[:title].index(".erb")
    t = params[:title].split(".")
    @title = t[0]
    if t.size == 3
      layout = File.read("views/posts/_#{t[1]}.erb")
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
      i.date = atime
    end
  end
  content.to_xml
end
  
def update_blog
  `cd views/posts;git pull`
  `mkdir public/images` unless File.exists?("public/images")
  `cp -r views/posts/images/* public/images/`
  "blog updated"
end

get '/update_blog' do #manual update
  update_blog
end

post '/update_blog' do # for github post-commit hook
  update_blog
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
