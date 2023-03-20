require "active_record"
require "active_enquo"

ActiveEnquo.root_key = Enquo::RootKey::Static.new("f91c5017a2d946403cc90a688266ff32d186aa2a00efd34dcaa86be802e179d0")

DBTYPE = ENV.fetch("DBTYPE")

case DBTYPE
when "postgresql"
	require "pg"
else
	raise "Unsupported DBTYPE: #{DBTYPE.inspect}"
end

class People < ActiveRecord::Base
end

ActiveRecord::Base.establish_connection(adapter: DBTYPE)
