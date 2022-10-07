class Text < ActiveRecord::Base
end

class SortableText < ActiveRecord::Base
	enquo_attr :value, enable_reduced_security_operations: true
end

class UnqueryableText < ActiveRecord::Base
	enquo_attr :value, no_query: true
end
