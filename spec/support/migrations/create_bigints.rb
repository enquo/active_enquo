class CreateBigints < ActiveRecord::Migration[6.0]
	def change
		create_table :bigints do |t|
			t.column :value, :enquo_bigint
			t.string :notes
		end
	end
end
