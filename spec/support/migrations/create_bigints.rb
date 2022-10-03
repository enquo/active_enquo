class CreateBigints < ActiveRecord::Migration[6.0]
	def change
		create_table :bigints do |t|
			t.column :value, :enquo_bigint
			t.string :notes
		end
	end
end

class CreateSortableBigints < ActiveRecord::Migration[6.0]
	def change
		create_table :sortable_bigints do |t|
			t.column :value, :enquo_bigint
			t.string :notes
		end
	end
end

class CreateUnqueryableBigints < ActiveRecord::Migration[6.0]
	def change
		create_table :unqueryable_bigints do |t|
			t.column :value, :enquo_bigint
			t.string :notes
		end
	end
end
