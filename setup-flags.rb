#! /usr/bin/env ruby

require 'pg'
require 'csv'
require 'yaml'

if ARGV.length < 3
  puts "setup <dbstring> <s3bucketname> <root>"
  return
end

@conn = PG::Connection.new(ARGV.shift)

@bucket = ARGV.shift

unless @bucket == '-'
  require 'aws-sdk-s3'
  @s3 = Aws::S3::Client.new
end

def upload(flags, a)
  response = @s3.put_object(
    bucket: @bucket,
    body: File.new(a, "r"),
    key: a
  )

  if !response.etag
    raise StandardError.new("Error uploading to bucket")
  end

  uri = "http://#{@bucket}.s3-website.#{ENV['AWS_REGION']}.amazonaws.com/#{a}"

  flags.each do |f|
    puts ("Uploading #{uri} for flag id #{f}")
    @conn.exec_params(<<-END_SQL, [a, uri, f])
      INSERT INTO attachments 
        (name, uri, flag_id)
      VALUES 
        ($1, $2, $3)
    END_SQL
  end
end

def normalize(f)
  f.gsub!('}', '.')
  f.gsub!('{', '.')
  f.gsub!('_', '.')
  f.downcase!

  f = "^#{f}$"

  puts "Normalized to: #{f}"
  return f
end

def walk(root)
  Dir.chdir(root)
  puts "Entered #{Dir.pwd}"

  Dir.children('.').each do |d|
    next unless Dir.exists?(d)
    Dir.chdir(d)
    puts "Entered #{Dir.pwd}"
    if Dir.children('.').include?"flags.yaml"
      yml = YAML.load(IO.read("flags.yaml"))

      mf_tags = {}

      yml['metaflags'].each do |mf|
        name = mf['name']
        desc = mf['desc']
        points = mf['points']

        if points.nil?
          puts "SKIPPING METAFLAG WITH MISSING MANDATORY FIELDS"
          next
        end
        

        f = @conn.exec_params(<<-END_SQL, [name, desc, points])
          INSERT INTO metaflags
            (name, description, points)
          VALUES
            ($1, $2, $3)
          RETURNING id, description
        END_SQL
        mf_tags[mf['tag']] = [f.first['id'], f.first['description']]
      end

      yml['flags'].each do |f|
        name = f['name']
        desc = f['desc'].nil? ? '' : f['desc']
        points = f['points']
        regexp = normalize(f['regexp'])
        meta_tag = f['meta']
        bonus = f['bonus'] ? f['bonus'] : false
        visible = f['hidden'] ? !f['hidden'] : meta_tag ? false : !bonus

        meta_id = nil
        if meta_tag
          meta_id = mf_tags[meta_tag][0]
          desc = mf_tags[meta_tag][1]
        end

        if name.nil? or points.nil? or regexp.nil?
          puts "SKIPPING FLAG WITH MISSING MANDATORY FIELDS!"
          next
        end

        f = @conn.exec_params(<<-END_SQL, [name, desc, points, regexp, visible, meta_id, bonus])
          INSERT INTO flags
            (name, description, points, regexp, visible, parent, bonus)
          VALUES
            ($1, $2, $3, $4, $5, $6, $7)
          RETURNING id
        END_SQL
      end

      @conn.exec("REFRESH MATERIALIZED VIEW v_solves")

      if Dir.children('.').include?"attachments" and @bucket != '-'
        puts "Uploading attachments"
        Dir.chdir("attachments");
        Dir.children('.').each do |a|
          upload(flags, a) unless a[0] == '.'
        end
        Dir.chdir('..')
      end
    else
      puts "Does not appear to be a challenge dir"
    end
    Dir.chdir('..')
  end
end

walk(ARGV.shift)
