require 'ice_cube'
require 'todotxt'   # https://github.com/tylerdooling/todotxt-rb ; gem install todotxt-rb
require 'json'

def parse_recur_file_content(recur_file_content)
  recur_lines = recur_file_content.split("\n").reject { |e| e =~ /^#/ }
  if not recur_lines.all?{ |e| e =~ /^(@[0-9-]+ )?[A-Za-z;,_0-9\s]+ - / }
    raise "Bad line(s) found"
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
    end

    def show_next(fake_today: nil)
      @recur_entries.each do |recur|
        puts "Schedule: #{recur[0]} -- Next Day: #{make_schedule( recur[0] ).next_occurrence( fake_today ).strftime("%Y-%m-%d")} -- Text: #{recur[1]}"
      end

    end

    def add_actions(todo_list: todo, fake_today: Date.today, date_task_was_last_added: {}) # TodoTxt::List
      @recur_entries.each do |recur|
        schedule = make_schedule(recur[0])
        task = TodoTxt::Task.parse(recur[1])
        task[:created_at] = DateTime.now

        last_add = date_task_was_last_added[task.text]
        if last_add == nil
          last_add = Date.today - 1 # default is yesterday
        end
        
        if schedule.occurs_between?(last_add+1, fake_today)
          puts "- Recur matches: #{recur[0]} --- #{recur[1]}"
          date_task_was_last_added[task.text] = fake_today

          found_task = todo_list.select { |t| t.text == task.text && ! t.completed? }.first
          if found_task
            puts "    - Duplicate task exists: #{found_task.text}"
          else
            puts "    -  No duplicate found for #{recur[1]}"
            puts "    -  Adding #{recur[1]}"
            todo_list << task
          end
        end
      end

    end

end

def ice_recur_main
  Dir.chdir(ENV['TODO_DIR']) do
      recur_file_content = File.open("ice_recur.txt") do |f|
        f.read
      end

      todo_list = File.open("todo.txt") do |f|
        TodoTxt::List.from_file(f)
      end

      date_task_was_last_added = File.open("ice_recur_date_task_was_last_added.txt") do |f|
        JSON.parse(f.read)
      end

      lib = Ice_recur_lib.new recur_file_content
      lib.add_actions(todo_list: todo_list, date_task_was_last_added: date_task_was_last_added)

      File.open('todo.txt', 'w') do |f|
        todo_list.to_file(f)
      end

      File.open("ice_recur_date_task_was_last_added.txt", 'w') do |f|
        f << date_task_was_last_added.to_json
      end

      return 0
  end
end
