# frozen_string_literal: true

require 'sinatra/base'
require 'logger'

# App is the main application where all your logic & routing will go
class App < Sinatra::Base
  set :erb, escape_html: true
  enable :sessions
  enable :show_exceptions

  attr_reader :logger, :groups

  def initialize
    super
    @logger = Logger.new('log/app.log')
    @groups ||= begin
      groups_from_id = `id`.to_s.match(/groups=(.+)/)[1].split(',').map do |g|
        g.match(/\d+\((\w+)\)/)[1]
      end

      groups_from_id.select { |g| g.match?(/^P\w+/) }
    end
  end

  def title
    'Summer Instititue - Blender'
  end
  def projects_root
    "#{__dir__}/projects"
  end

  def project_dirs
    Dir.children(projects_root).reject { |dir| dir == 'input_files' }.sort_by(&:to_s)
  end

  def input_files_dir
    "#{projects_root}/input_files"
  end
  
  def copy_upload(input: nil, output: nil)
    input_sha = Pathname.new(input).file? ? Digest::SHA256.file(input) : nil
    output_sha = Pathname.new(output).file? ? Digest::SHA256.file(output) : nil
    return if input_sha.to_s == output_sha.to_s

    File.open(output, 'wb') do |f|
      f.write(input.read)
    end
  end
  get '/' do
    logger.info('requsting the index')
    @flash = session.delete(:flash) || { info: 'Welcome to Summer Institute!' }
    @project_dirs = project_dirs
    

    erb(:index)
  end


get '/delete/:dir' do
  FileUtils.rm_rf("#{projects_root}/#{params[:dir]}")
  session[:flash] = { info: "sucessfully deleted' #{params[:dir]}'"}
  redirect(url("/"))
end


  get '/information' do
    erb(:information)
  end

  get '/home' do
    erb(:home)
  end

  
 get '/projects/:dir' do
    if params[:dir] == 'new' || params[:dir] == 'input_files'
      erb :new_project
    else
      @dir = Pathname("#{projects_root}/#{params[:dir]}")
      @flash = session.delete(:flash)
         @uploaded_blend_files = Dir.glob("#{input_files_dir}/*.blend").map { |f| File.basename(f) }
         @project_name = @dir.basename.to_s.gsub('_', ' ').capitalize
      unless @dir.directory? || @dir.readable?
        session[:flash] = { danger: "#{@dir} does not exist" }
        redirect(url('/'))
      end
      @images = Dir.glob("#{@dir}/*.png")
      `touch #{@dir}/.frame_render_job_id`
      @frame_render_job_id = File.read("#{@dir}/.frame_render_job_id").chomp
      @frame_render_job_state = job_state(@frame_render_job_id)
      @frame_render_badge = badge(@frame_render_job_state)


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
  post '/render/frames' do
    logger.info("Trying to render frames with: #{params.inspect}")

    if params['blend_file'].nil?
      blend_file = "#{input_files_dir}/#{params[:uploaded_blend_file]}"
    else
      blend_file = "#{input_files_dir}/#{params['blend_file'][:filename]}"
      copy_upload(input: params['blend_file'][:tempfile], output: blend_file)
    end

    dir = params[:dir]
    basename = File.basename(blend_file, '.*')
    walltime = format('%02d:00:00', params[:num_hours])

    args = ['-J', "blender-#{basename}", '--parsable', '-A', params[:project_name]]
    args.concat ['--export', "BLEND_FILE_PATH=#{blend_file},OUTPUT_DIR=#{dir},FRAMES_RANGE=#{params[:frames_range]}"]
    args.concat ['-n', params[:num_cpus], '-t', walltime, '-M', 'pitzer']
    args.concat ['--output', "#{dir}/frame-render-%j.out"]
    output = `/bin/sbatch #{args.join(' ')}  #{__dir__}/render_frames.sh 2>&1`

    job_id = output.strip.split(';').first
    `echo #{job_id} > #{dir}/.frame_render_job_id`

    session[:flash] = { info: "submitted job #{job_id}" }
    redirect(url("/projects/#{dir.split('/').last}"))
  end
end
def job_state(job_id)
  state = `/bin/squeue -j #{job_id} -h -o '%t'`.chomp
  s = {
    '' => 'Completed',
    'R' => 'Running',
    'C' => 'Completed',
    'Q' => 'Queued',
    'CF' => 'Queued',
    'PD' => 'Queued',
  }[state]

  s.nil? ? 'Unknown' : s
end

def badge(state)
  {
    '' => 'warning',
    'Unknown' => 'warning',
    'Running' => 'success',
    'Queued' => 'info',
    'Completed' => 'primary',
  }[state.to_s]
end
