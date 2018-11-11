require 'ice_cube'
require 'todotxt'   # https://github.com/tylerdooling/todotxt-rb ; gem install todotxt-rb
require 'json'
require 'optparse'

def parse_recur_file_content(recur_file_content)
  recur_lines = recur_file_content.split("\n").reject { |e| e =~ /^#/ }
  #if not recur_lines.all?{ |e| e =~ /^(@[0-9-]+ )?[A-Za-z;,_0-9\s]*s - / }
  if not recur_lines.all?{ |e| e =~ /^\s*(@\d{4}-\d{1,2}-\d{1,2})?\s*([A-Za-z;,_0-9\s]*)\s-\s(.*)/ }
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
  more_than_startdate = false

  rulestr.split(%r{\s;\s}).each do |rulebit|
    more_than_startdate = true
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

  if more_than_startdate
    schedule.add_recurrence_rule rule
  end

  return schedule
end


class Ice_recur_lib

    def initialize(recur_file_content)
        @recur_entries = parse_recur_file_content(recur_file_content)
    end

    def show_next(fake_today: nil)
      @recur_entries.each do |recur|
        next_occurence_date = make_schedule( recur[0] ).next_occurrence( fake_today )
        if next_occurence_date
          puts "Schedule: #{recur[0]} -- Next Day: #{next_occurence_date.strftime("%Y-%m-%d")} -- Text: #{recur[1]}"
        end
      end

    end

    def add_actions(todo_list: todo, fake_today: Date.today, date_task_was_last_added: {}) # TodoTxt::List
      @recur_entries.each do |recur|
        schedule = make_schedule(recur[0])
        task = TodoTxt::Task.parse(recur[1])
        task[:created_at] = DateTime.now

        last_add = date_task_was_last_added[task.text]
        if last_add == nil
          last_add = Date.new(2000,1,1) # default is long time ago
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

  options = parse_command_line_options

  Dir.chdir(ENV['TODO_DIR']) do
      recur_file_content = File.open("ice_recur.txt") do |f|
        f.read
      end

      lib = Ice_recur_lib.new recur_file_content

      if options[:show_next]
        lib.show_next
        return 0
      end

      todo_list = File.open("todo.txt") do |f|
        TodoTxt::List.from_file(f)
      end

      date_task_was_last_added = 
        if File.file?("ice_recur_date_task_was_last_added.txt")
          File.open("ice_recur_date_task_was_last_added.txt") do |f|
            JSON.parse(f.read)
          end.transform_values{|v| Date.parse v}
        else
          {}
        end

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

def parse_command_line_options
options = {}
OptionParser.new do |opts|
  #opts.banner = "Usage: example.rb [options]"
  opts.banner = %{
  ice_recur

  A recurring item generator for todo.txt.  Yes, there are like 14 of these, but I couldn't find a single one that could do "every 2 weeks", so I wrote my own.

  It's called ice_recur because it relies, heavily, on the ice_cube recurring schedule library, and to avoid collision with the other recur action I was using at the time.

  This script goes in $TODO_DIR/actions/

  It requires ice_cube and todotxt, although I can't see how you'd be seeing this message if you hadn't figured that out.

  You put your entries in $TODO_DIR/ice_recur.txt , and add something like this:

      ~/bin/todo.sh ice_recur

  to your crontab, to run once a day.

  Every entry that matches the current day will be added, as long as there is no other entry with the same text content.

  Recurrence Format
  -----------------

  Entries look like:

  @[optional starting date] [timing] - [task]

  like:

  @2016-02-03 Weekly ; day Monday - (B) Mon Recur Test

  Where [timing] is a sequence of timing specifiers seperated by " ; ".  Each timing specifier makes the item more specific.

  The starting date is entirely optional; if specified it 

  Timing Specifiers
  -----------------

  All the timing specifiers, and the sequencing behaviour, is just https://github.com/seejohnrun/ice_cube , except as plain text.

  The code just calls IceCube::Rule methods using whatever you specify.

  Checking The Run
  ----------------

  Run "todo ice_recur check" to check if ice_recur has run to completion in the last 2 days.  Pass an email address as an argument; if the check fails, it'll send email to that address.

  Examples
  --------

  In general, you can check if a timing setup does what you want using the "-s" argument, which will show you when that line will next trigger.


  daily - (A) Runs every day; includes today
  daily 2 - (B) Runs every other day; includes today
  @2016-03-10 daily 2 - Runs every other day, starting on the day specified (which may or may not include today)
  weekly ; day Friday, Sunday - Runs every Friday and Saturday
  monthly ; day_of_month 11, 13 - Runs on the 11th and 13th of every month
  @2016-03-07 Weekly 2 ; day Thursday - Runs on Thursday every second week starting on the first Thursday after the day specified.
  @2016-03-01 Monthly 3 - Runs every 3 months starting on the day specified (so, occurs on the first day of the month; next occurence is 2016-06-01)
  @2016-01-04 Yearly - Runs every year starting on the day specifiod (so, occurs on the 4th of January)

}

  opts.on("-s", "--show-next", "Show next occurences") do |v|
    options[:show_next] = v
  end
end.parse!

options
end
