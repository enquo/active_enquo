class CreateBooleans < ActiveRecord::Migration[6.0]
	def change
		create_table :booleans do |t|
			t.column :value, :enquo_boolean
			t.string :notes
		end
	end
end

class CreateSortableBooleans < ActiveRecord::Migration[6.0]
	def change
		create_table :sortable_booleans do |t|
			t.column :value, :enquo_boolean
			t.string :notes
		end
	end
end

class CreateUnqueryableBooleans < ActiveRecord::Migration[6.0]
	def change
		create_table :unqueryable_booleans do |t|
			t.column :value, :enquo_boolean
			t.string :notes
		end
	end
end
