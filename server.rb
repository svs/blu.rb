require 'rubygems'
require 'sinatra'
require 'erb'
require 'rss/maker'

def entries
  @posts = {}
  (Dir.entries("views/posts/").reject{|p| /[#~]/.match(p) != nil} - [".","..","layout.erb",".git"]).each do |post| 
    @posts[File.atime("views/posts/#{post}")] = post
  end
  @posts
end

get "/" do
  redirect "/index.html"
end

get "/blog/:title" do
  if params[:title].index(".erb")
    erb :"posts/#{params[:title].gsub(".erb","")}"
  else
    File.read("views/posts/#{params[:title]}")
  end
end

get "/blog" do
  entries
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
      i.link = host_root + "/blog/#{url_encode(entry)}"
      i.date = atime
    end
  end
  content.to_xml
end
  
get '/update_blog' do
  `cd views/posts;git pull`
  "blog updated"
end

post '/update_blog' do
  `cd views/posts;git pull origin master`
  "blog updated"
end
