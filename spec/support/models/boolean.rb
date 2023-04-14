class Boolean < ActiveRecord::Base
end

class SortableBoolean < ActiveRecord::Base
	enquo_attr :value, enable_reduced_security_operations: true
end

class UnqueryableBoolean < ActiveRecord::Base
	enquo_attr :value, no_query: true
end
