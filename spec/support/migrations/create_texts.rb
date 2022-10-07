class CreateTexts < ActiveRecord::Migration[6.0]
	def change
		create_table :texts do |t|
			t.column :value, :enquo_text
			t.string :notes
		end
	end
end

class CreateSortableTexts < ActiveRecord::Migration[6.0]
	def change
		create_table :sortable_texts do |t|
			t.column :value, :enquo_text
			t.string :notes
		end
	end
end

class CreateUnqueryableTexts < ActiveRecord::Migration[6.0]
	def change
		create_table :unqueryable_texts do |t|
			t.column :value, :enquo_text
			t.string :notes
		end
	end
end
