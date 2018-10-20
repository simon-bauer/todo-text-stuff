require_relative '../ice_recur_lib'

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


end

RSpec.describe "Ice_recur_lib" do
  it "show_next shows next occurence of each entry/line in the recur file" do
    expect(STDOUT).to receive(:puts).with("Schedule: @2018-01-01 weekly -- Next Day: 2018-01-08 -- Text: Call mom")

    recur_file_content = "@2018-01-01 weekly - Call mom\n"
    lib = Ice_recur_lib.new recur_file_content
    lib.show_next(Date.new(2018,01,02))
  end
end
