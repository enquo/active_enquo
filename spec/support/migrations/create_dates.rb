class CreateEnDates < ActiveRecord::Migration[6.0]
	def change
		create_table :en_dates do |t|
			t.column :value, :enquo_date
			t.string :notes
		end
	end
end

class CreateSortableDates < ActiveRecord::Migration[6.0]
	def change
		create_table :sortable_dates do |t|
			t.column :value, :enquo_date
			t.string :notes
		end
	end
end

class CreateUnqueryableDates < ActiveRecord::Migration[6.0]
	def change
		create_table :unqueryable_dates do |t|
			t.column :value, :enquo_date
			t.string :notes
		end
	end
end
