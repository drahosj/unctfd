#! /usr/bin/env ruby

require 'aws-sdk-s3'
require 'pg'
require 'csv'

if ARGV.length < 3
  puts "setup <dbname> <s3bucketname> <root>"
  return
end

@conn = PG::Connection.new(dbname: ARGV.shift)

@bucket = ARGV.shift


@s3 = Aws::S3::Client.new

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
  replace = '{}_'
  f.gsub!('}', '.')
  f.gsub!('{', '.')
  f.gsub!('_', '.')
  return f.downcase!
end

def walk(root)
  Dir.chdir(root)
  puts "Entered #{Dir.pwd}"

  Dir.children('.').each do |d|
    next unless Dir.exists?(d)
    Dir.chdir(d)
    puts "Entered #{Dir.pwd}"
    if Dir.children('.').include?"flags.csv"
      csv = CSV.new(IO.read("flags.csv"), headers: true);
      desc = ''

      if Dir.children('.').include?"description.txt"
        desc = IO.read("description.txt")
      end

      flags = []

      csv.each do |r|
        r = r.to_a
        p r
        name = r[0].last
        points = r[1].last
        regexp = normalize(r[2].last)
        visible = r[3].last
        f = @conn.exec_params(<<-END_SQL, [name, desc, points, regexp, visible])
          INSERT INTO flags
            (name, description, points, regexp, visible)
          VALUES
            ($1, $2, $3, $4, $5)
          RETURNING id
        END_SQL
        p f
        flags << f[0]['id']
        p flags
      end

      if Dir.children('.').include?"attachments"
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
