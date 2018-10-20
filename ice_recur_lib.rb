require 'ice_cube'
require 'todotxt'   # https://github.com/tylerdooling/todotxt-rb ; gem install todotxt-rb

def parse_recur_file_content(recur_file_content)
  recur_lines = recur_file_content.split("\n").reject { |e| e =~ %r{^#} }
  bad_lines = recur_lines.reject { |e| e =~ %r{^(@[0-9-]+ )?[A-Za-z;,_0-9\s]+ - } }
  if bad_lines.length > 0
    raise "Bad lines found: \n#{bad_lines.join("\n")}"
  end

  recur_entries = []
  recur_lines.each do |recur|
    schedstr, taskstr = recur.strip.split(%r{\s+-\s+}, 2)
    recur_entries << [schedstr, taskstr]
  end
  recur_entries
end


def make_schedule( rulestr )
  # Get the start date, if any
  startdate = Time.now.to_date
  if rulestr =~ %r{^\s*@}
    startdate = Date.parse(rulestr.sub(%r{^\s*@(\S+)\s.*},'\1'))
    rulestr = rulestr.dup.sub!(%r{^\s*@\S+},'')
  end

  rule=IceCube::Rule
  schedule = IceCube::Schedule.new(startdate.to_time)

  rulestr.split(%r{\s;\s}).each do |rulebit|
    method, argstr = rulebit.strip.split(%r{\s+}, 2)
    method.downcase!

    args = []

    if argstr
      args = argstr.strip.split(%r{\s*,\s*})

      args.map! do |arg|
        if arg =~ %r{day\s*$}
          arg.downcase.to_sym
        elsif arg =~ %r{[0-9]+}
          arg = arg.to_i
        else
          arg
        end
      end
    end

    rule = rule.send(method, *args)
  end

  schedule.add_recurrence_rule rule

  return schedule
end


class Ice_recur_lib

    def initialize(recur_file_content)
        @recur_entries = parse_recur_file_content(recur_file_content)
        #@recur_file = File.join(ENV['TODO_DIR'], 'ice_recur.txt')
        #@completed_file = File.join(ENV['TODO_DIR'], '.ice_recur_completed')
    end

    def show_next(from = nil)
      @recur_entries.each do |recur|
        puts "Schedule: #{recur[0]} -- Next Day: #{make_schedule( recur[0] ).next_occurrence( from ).strftime("%Y-%m-%d")} -- Text: #{recur[1]}"
      end

    end

    def default
      # Get our recur entries
      # Drop everything that looks like a comment or blank
      recur_entries = File.read(@recur_file).split("\n").reject { |e| e =~ %r{(^\s*#|^\s*$)} }
      bad_entries = recur_entries.reject { |e| e =~ %r{^(@[0-9-]+ )?[A-Za-z;,_0-9\s]+ - } }
      if bad_entries.length > 0
        raise "Bad entries found in #{@recur_file}: \n#{bad_entries.join("\n")}"
      end

      # Make a backup
      todo_file = File.join(ENV['TODO_DIR'], 'todo.txt')
      orig_todo_data = File.read(todo_file)
      orig_todo_time = File.mtime(todo_file).to_i

      begin
        File.open(todo_file, 'r+') do |todo_fh|
          todo_list = TodoTxt::List.from_file(todo_fh)

          recur_entries.each do |recur|
            schedstr, taskstr = recur.strip.split(%r{\s+-\s+}, 2)
            if make_schedule( schedstr ).occurs_on?(Date.today)
              puts "- Recur matches today: #{schedstr} --- #{taskstr}"
              task = TodoTxt::Task.parse(taskstr)
              task[:created_at] = DateTime.now
              found_task = todo_list.select { |t| t.text == task.text && ! t.completed? }.first
              if found_task
                puts "    - Duplicate task exists: #{found_task.text}"
              else
                puts "    -  No duplicate found for #{taskstr}"
                puts "    -  Adding #{taskstr}"

                todo_list << task
                todo_fh.rewind
                todo_fh.truncate(todo_fh.pos)
                todo_list.to_file(todo_fh)
                todo_fh.write("\n")
              end
            end
          end
        end
      rescue => e
        if File.mtime(todo_file).to_i != orig_todo_time
          puts "FAILURE: Something went wrong; reverting #{todo_file}: #{e}; #{e.backtrace.join("\n")}"
          File.open(todo_file, 'w') { |file| file.puts orig_todo_data }
        else
          puts "FAILURE: Something went wrong: #{e}; #{e.backtrace.join("\n")}"
        end
        exit 1
      end

      # Mark the "we've actually run" file
      require 'fileutils'
      FileUtils.touch @completed_file
    end

end
