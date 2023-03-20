class CreatePeopleTable < ActiveRecord::Migration[ENV.fetch("AR_VERSION", "7.0").to_f]
	def change
		create_table :people do |t|
			t.string :first_name
			t.string :last_name
			t.date :date_of_birth

			t.timestamps
		end
	end
end
