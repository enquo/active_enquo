class Bigint < ActiveRecord::Base
end

class SortableBigint < ActiveRecord::Base
	enquo_attr :value, enable_reduced_security_operations: true
end

class UnqueryableBigint < ActiveRecord::Base
	enquo_attr :value, no_query: true
end
