# frozen_string_literal: true

require 'sinatra/base'
require 'logger'

# App is the main application where all your logic & routing will go
class App < Sinatra::Base
  set :erb, escape_html: true
  enable :sessions
  enable :show_exceptions

  attr_reader :logger

  def initialize
    super
    @logger = Logger.new('log/app.log')
  end

  def title
    'Summer Instititue - Blender'
  end
  def projects_root
    "#{__dir__}/projects"
  end
  get '/' do
    logger.info('requsting the index')
    @flash = session.delete(:flash) || { info: 'Welcome to Summer Institute!' }
    erb(:index)
  end

  get '/information' do
    erb(:information)
  end

  
 get '/projects/:dir' do
    if params[:dir] == 'new' || params[:dir] == 'input_files'
      erb :new_project
    else
      @dir = Pathname("#{projects_root}/#{params[:dir]}")
      @flash = session.delete(:flash)

      unless @dir.directory? || @dir.readable?
        session[:flash] = { danger: "#{@dir} does not exist" }
        redirect(url('/'))
      end


      erb :show_project
    end
  end

  post '/projects/new' do
    logger.info("Trying to render frames with: #{params.inspect}")
    
     dir = params[:name].downcase.gsub(' ', '_')
    "#{projects_root}/#{dir}".tap { |d| FileUtils.mkdir_p(d) }

     session[:flash] = { info: "made new project '#{params[:name]}'" }
     redirect(url("/projects/#{dir}"))
  end
end

