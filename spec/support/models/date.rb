class EnDate < ActiveRecord::Base
end

class SortableDate < ActiveRecord::Base
	enquo_attr :value, enable_reduced_security_operations: true
end

class UnqueryableDate < ActiveRecord::Base
	enquo_attr :value, no_query: true
end
