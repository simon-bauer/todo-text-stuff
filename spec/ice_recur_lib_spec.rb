require_relative '../ice_recur_lib'
require 'tmpdir'
require 'pry'

RSpec.describe "parse_recur_file_content" do
  it "each line is parsed into schedule and action entry" do
    recur_entries = parse_recur_file_content("@2018-01-01 weekly - Call mom\n@2018-01-02 weekly - Call dad")
    expect(recur_entries.length).to eq(2)
    expect(recur_entries[0][0]).to eq("@2018-01-01 weekly")
    expect(recur_entries[0][1]).to eq("Call mom")
    expect(recur_entries[1][0]).to eq("@2018-01-02 weekly")
    expect(recur_entries[1][1]).to eq("Call dad")
  end

  it "lines starting with '#' are ignored" do
    recur_entries = parse_recur_file_content("#@2018-01-01 weekly - Call mom")
    expect(recur_entries.length).to eq(0)
  end

  it "invalid lines lead to an exception" do
    expect{ parse_recur_file_content("? - Call mom") }.to raise_error(RuntimeError)
  end
end

RSpec.describe "make_schedule" do
  it "includes today for 'daily'" do
      schedule = make_schedule( "daily" )
      expect( schedule.occurs_on?(Date.today) ).to be true
  end

  it "includes today, and 2 days from now, but not tomorrow for 'daily 2'" do
      schedule = make_schedule( "daily 2" )
      expect( schedule.occurs_on?(Date.today) ).to be true
      expect( schedule.occurs_on?(Date.today + 1) ).to be false
      expect( schedule.occurs_on?(Date.today + 2) ).to be true
  end

  it "includes startdate and every second date following for 'daily 2' with startdate" do
      schedule = make_schedule( "@2000-01-01 daily 2" )

      expect( schedule.occurs_on?(Date.new(1999,12,30)) ).to be false
      expect( schedule.occurs_on?(Date.new(1999,12,31)) ).to be false
      expect( schedule.occurs_on?(Date.new(2000,01, 1)) ).to be true
      expect( schedule.occurs_on?(Date.new(2000,01, 2)) ).to be false
      expect( schedule.occurs_on?(Date.new(2000,01, 3)) ).to be true
      expect( schedule.occurs_on?(Date.new(2000,01, 4)) ).to be false
  end

  it "includes every wednesday and friday beginning with startdate 'weekly ; day 3, 5' with startdate" do
      schedule = make_schedule( "@2018-01-01 weekly ; day 3, 5" ) # 2018-01-01 was a monday

      expect( schedule.occurs_on?(Date.new(2018,01, 1)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01, 2)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01, 3)) ).to be true
      expect( schedule.occurs_on?(Date.new(2018,01, 4)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01, 5)) ).to be true
      expect( schedule.occurs_on?(Date.new(2018,01, 6)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01, 7)) ).to be false

      expect( schedule.occurs_on?(Date.new(2018,01, 8)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01, 9)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01,10)) ).to be true
      expect( schedule.occurs_on?(Date.new(2018,01,11)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01,12)) ).to be true
      expect( schedule.occurs_on?(Date.new(2018,01,13)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01,14)) ).to be false


      schedule = make_schedule( "@2018-04-01 weekly ; day 3, 5" ) # 2018-04-01 was a sunday

      expect( schedule.occurs_on?(Date.new(2018,04, 1)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,04, 2)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,04, 3)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,04, 4)) ).to be true
      expect( schedule.occurs_on?(Date.new(2018,04, 5)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,04, 6)) ).to be true
  end

  it "includes every monday beginning with startdate 'weekly ; day monday' with startdate" do
      schedule = make_schedule( "@2018-01-01 weekly ; day monday" ) # 2018-01-01 was a monday

      expect( schedule.occurs_on?(Date.new(2018,01, 1)) ).to be true
      expect( schedule.occurs_on?(Date.new(2018,01, 2)) ).to be false
  end

  it "includes every monday beginning with startdate 'weekly ; day monday' with startdate" do
      schedule = make_schedule( "@2018-01-01 monthly ; day_of_month 15, 16" ) # 2018-01-01 was a monday

      expect( schedule.occurs_on?(Date.new(2018,01, 1)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01,14)) ).to be false
      expect( schedule.occurs_on?(Date.new(2018,01,15)) ).to be true
      expect( schedule.occurs_on?(Date.new(2018,01,16)) ).to be true
      expect( schedule.occurs_on?(Date.new(2018,01,17)) ).to be false
  end

  it "occurs_between" do
      schedule = make_schedule( "@2000-01-01 daily 3" )

      expect( schedule.occurs_between?(Date.new(2000,1,1), Date.new(2000,1,1)) ).to be true
      expect( schedule.occurs_between?(Date.new(2000,1,1), Date.new(2000,1,2)) ).to be true
      expect( schedule.occurs_between?(Date.new(2000,1,2), Date.new(2000,1,3)) ).to be false
      expect( schedule.occurs_between?(Date.new(2000,1,3), Date.new(2000,1,4)) ).to be true

      expect( schedule.occurs_between?(Date.new(2000,1,3), Date.new(2000,1,5)) ).to be true
  end

end

RSpec.describe "Ice_recur_lib" do
  it "show_next shows next occurence of each entry/line in the recur file" do
    expect($stdout).to receive(:puts).with("Schedule: @2018-01-01 weekly -- Next Day: 2018-01-08 -- Text: Call mom")

    recur_file_content = "@2018-01-01 weekly - Call mom\n"
    lib = Ice_recur_lib.new recur_file_content
    lib.show_next(fake_today: Date.new(2018,01,02))
  end


  it "add actions if today is an occurence" do
    recur_file_content = "@2018-01-01 daily - Call mom\n"
    lib = Ice_recur_lib.new recur_file_content
    todo_list = TodoTxt::List.new([TodoTxt::Task.parse("Call dad")])

    allow($stdout).to receive(:puts)
    lib.add_actions(todo_list: todo_list)

    expect( todo_list.length ).to eq(2)
    expect( todo_list[0].text ).to eq("Call dad")
    expect( todo_list[1].text ).to eq("Call mom")
  end

  it "does not add actions if today is no occurence" do
    recur_file_content = "@2018-01-01 daily 2 - Call mom\n"
    lib = Ice_recur_lib.new recur_file_content
    todo_list = TodoTxt::List.new([TodoTxt::Task.parse("Call dad")])

    fake_today = Date.new(2018,1,2)

    allow($stdout).to receive(:puts)
    lib.add_actions(todo_list: todo_list, fake_today: fake_today)

    expect( todo_list.length ).to eq(1)
    expect( todo_list[0].text ).to eq("Call dad")
  end

  it "add_actions only if not already in todo list" do
    recur_file_content = "@2018-01-01 daily - Call mom\n"
    lib = Ice_recur_lib.new recur_file_content
    todo_list = TodoTxt::List.new([TodoTxt::Task.parse("Call mom")])

    allow($stdout).to receive(:puts)
    lib.add_actions(todo_list: todo_list)

    expect( todo_list.length ).to eq(1)
    expect( todo_list[0].text ).to eq("Call mom")
  end

  it "add_actions considering the date of the last adding" do
    recur_file_content = "@2018-01-01 daily 2 - Call mom\n"
    lib = Ice_recur_lib.new recur_file_content
    todo_list = TodoTxt::List.new([TodoTxt::Task.parse("Call dad")])

    fake_today = Date.new(2018,1,4)
    date_task_was_last_added = {"Call mom" => Date.new(2018,1,1)}

    allow($stdout).to receive(:puts)
    lib.add_actions(todo_list: todo_list, fake_today: fake_today, date_task_was_last_added: date_task_was_last_added)

    expect( todo_list.length ).to eq(2)
    expect( todo_list[0].text ).to eq("Call dad")
    expect( todo_list[1].text ).to eq("Call mom")

    expect( date_task_was_last_added["Call mom"] ).to eq(fake_today)
  end

end

RSpec.describe "ice_recur_main" do
  it "happy path" do
    # in:  ENV, todotxt-file, recur-file, date-last-added-file
    ENV['TODO_DIR'] = Dir.tmpdir


    allow(File).to receive(:open).and_call_original

    todotxt_input = StringIO.new("Call dad\n")
    expect(todotxt_input).to receive(:close)
    allow(File).to receive(:open).with(File.join(ENV['TODO_DIR'], 'todo.txt')).and_return(todotxt_input)

    todotxt_output = StringIO.new
    expect(todotxt_output).to receive(:close)
    allow(File).to receive(:open).with(File.join(ENV['TODO_DIR'], 'todo.txt'),'w').and_return(todotxt_output)

    ice_recur_input = StringIO.new("@2018-01-01 daily 1 - Call mom\n")
    expect(ice_recur_input).to receive(:close)
    allow(File).to receive(:open).with(File.join(ENV['TODO_DIR'], "ice_recur.txt")).and_return(ice_recur_input)

    date_task_was_last_added_input = StringIO.new("{\"Call dad\":\"2018-01-01\"}")
    #expect(date_task_was_last_added_input).to receive(:close)
    allow(File).to receive(:open).with(File.join(ENV['TODO_DIR'], "ice_recur_date_task_was_last_added.txt")).and_return(date_task_was_last_added_input)

    date_task_was_last_added_output = StringIO.new
    #expect(date_task_was_last_added_output).to receive(:close)
    allow(File).to receive(:open).with(File.join(ENV['TODO_DIR'], "ice_recur_date_task_was_last_added.txt"),'w').and_return(date_task_was_last_added_output)


    # when
    return_value = ice_recur_main
    
    # out: shell-return-code, todotxt-file, date-last-added-file
    expect( return_value ).to eq(0)

    todotxt_output.rewind
    expect( todotxt_output.read ).to eq("Call dad\n#{Date.today.to_s} Call mom")
  end
end

