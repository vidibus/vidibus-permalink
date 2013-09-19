# Helper for stubbing time. Define String to be set as Time.now.
# Usage:
#   stub_time('01.01.2010 14:00')
#   stub_time(2.days.ago)
#
def stub_time!(string = nil)
  string ||= Time.now.to_s(:db)
  now = Time.parse(string.to_s)
  stub(Time).now {now}
  now
end
