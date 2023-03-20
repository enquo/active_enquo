class EncryptPeopleData < ActiveRecord::Migration[ENV.fetch("AR_VERSION", "7.0").to_f]
	def up
		rename_column :people, :first_name, :first_name_plaintext
		rename_column :people, :last_name, :last_name_plaintext
		rename_column :people, :date_of_birth, :date_of_birth_plaintext

		add_column :people, :first_name, :enquo_text
		add_column :people, :last_name, :enquo_text
		add_column :people, :date_of_birth, :enquo_date

		People.enquo_encrypt_columns(
			{
				first_name_plaintext: :first_name,
				last_name_plaintext: :last_name,
				date_of_birth_plaintext: :date_of_birth,
			},
			# Smol batch size exercises the batching functionality
			batch_size: 5
		)

		remove_column :people, :first_name_plaintext
		remove_column :people, :last_name_plaintext
		remove_column :people, :date_of_birth_plaintext
	end
end
