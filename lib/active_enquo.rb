require "active_record/connection_adapters/postgresql_adapter"
require "active_support/lazy_load_hooks"

require "date"
require "enquo"
require "time"

module ActiveEnquo
	def self.root_key=(k)
		@root = Enquo::Root.new(k)
	end

	def self.root
		if @root.nil?
			raise RuntimeError, "The ActiveEnquo root key must be set before calling ActiveEnquo.root"
		end

		@root
	end

	RootKey = Enquo::RootKey

	module ActiveRecord
		module ModelExtension
			extend ActiveSupport::Concern

			def _read_attribute(attr_name, &block)
				t = self.class.attribute_types[attr_name]
				if t.is_a?(::ActiveEnquo::Type)
					relation = self.class.arel_table.name
					value = @attributes.fetch_value(attr_name, &block)
					return nil if value.nil?
					field = ::ActiveEnquo.root.field(relation, attr_name)
					begin
						t.decrypt(value, @attributes.fetch_value(@primary_key).to_s, field)
					rescue Enquo::Error
						# If the record had not yet been inserted into the database at the time the
						# attribute was originally written, then that attribute's context will be empty.
						# This is troublesome, but it's tricky to solve at this layer, so we'll have to
						# take the risk and try and decryption with empty context.
						t.decrypt(value, "", field)
					end
				else
					super
				end
			end

			def _write_attribute(attr_name, value)
				t = self.class.attribute_types[attr_name]
				if t.is_a?(::ActiveEnquo::Type)
					relation = self.class.arel_table.name
					field = ::ActiveEnquo.root.field(relation, attr_name)
					attr_opts = self.class.enquo_attribute_options.fetch(attr_name.to_sym, {})
					safety = if attr_opts[:enable_reduced_security_operations]
						:unsafe
					end
					db_value = t.encrypt(value, @attributes.fetch_value(@primary_key).to_s, field, safety: safety, no_query: attr_opts[:no_query])
					@attributes.write_from_user(attr_name, db_value)
				else
					super
				end
			end

			module ClassMethods
				def enquo(attr_name, value)
					t = self.attribute_types[attr_name.to_s]
					if t.is_a?(::ActiveEnquo::Type)
						relation = self.arel_table.name
						field = ::ActiveEnquo.root.field(relation, attr_name)
						t.encrypt(value, "", field, safety: :unsafe)
					else
						raise ArgumentError, "Cannot produce encrypted value on a non-enquo attribute '#{attr_name}'"
					end
				end

				def enquo_attr(attr_name, opts)
					enquo_attribute_options[attr_name] = @enquo_attribute_options[attr_name].merge(opts)
				end

				def enquo_attribute_options
					@enquo_attribute_options ||= Hash.new({})
				end

				def enquo_encrypt_columns(column_map, batch_size: 10_000)
					plaintext_columns = column_map.keys
					relation = self.arel_table.name
					in_progress = true

					while in_progress
						self.transaction do
							# The .where("0=1") here is a dummy condition so that the q.or in the .each will work properly
							q = self.select(self.primary_key).select(plaintext_columns).where("0=1")
							column_map.each do |pt_col, ct_col|
								q = q.or(self.where(ct_col => nil).where.not(pt_col => nil))
							end

							q = q.limit(batch_size).lock

							rows = ::ActiveRecord::Base.connection.exec_query(q.to_sql)
							if rows.length == 0
								in_progress = false
							else
								rows.each do |row|
									values = Hash[column_map.map do |pt_col, ct_col|
										field = ::ActiveEnquo.root.field(relation, ct_col)
										attr_opts = self.enquo_attribute_options.fetch(ct_col.to_sym, {})
										safety = if attr_opts[:enable_reduced_security_operations]
											:unsafe
										end
										t = self.attribute_types[ct_col.to_s]
										db_value = t.encrypt(row[pt_col.to_s], row[self.primary_key].to_s, field, safety: safety, no_query: attr_opts[:no_query])

										[ct_col, db_value]
									end]

									People.where(self.primary_key => row[self.primary_key]).update_all(values)
								end
							end
						end
					end
				end
			end
		end

		module TableDefinitionExtension
			def enquo_bigint(name, **options)
				column(name, :enquo_bigint, **options)
			end

			def enquo_date(name, **options)
				column(name, :enquo_date, **options)
			end

			def enquo_text(name, **options)
				column(name, :enquo_text, **options)
			end
		end
	end

	module Postgres
		module ConnectionAdapter
			def initialize_type_map(m = type_map)
				m.register_type "enquo_bigint", ActiveEnquo::Type::Bigint.new
				m.register_type "enquo_date", ActiveEnquo::Type::Date.new
				m.register_type "enquo_text", ActiveEnquo::Type::Text.new

				super
			end
		end
	end

	class Type < ::ActiveRecord::Type::Value
		class Bigint < Type
			def type
				:enquo_bigint
			end

			def encrypt(value, context, field, safety: true, no_query: false)
				field.encrypt_i64(value, context, safety: safety, no_query: no_query)
			end

			def decrypt(value, context, field)
				field.decrypt_i64(value, context)
			end
		end

		class Date < Type
			def type
				:enquo_date
			end

			def encrypt(value, context, field, safety: true, no_query: false)
				value = cast_to_date(value)
				field.encrypt_date(value, context, safety: safety, no_query: no_query)
			end

			def decrypt(value, context, field)
				field.decrypt_date(value, context)
			end

			private

			def cast_to_date(value)
				if Date === value
					value
				elsif value.respond_to?(:to_date)
					value.to_date
				else
					Time.parse(value.to_s).to_date
				end
			end
		end

		class Text < Type
			def type
				:enquo_text
			end

			def encrypt(value, context, field, safety: true, no_query: false)
				field.encrypt_text(value, context, safety: safety, no_query: no_query)
			end

			def decrypt(value, context, field)
				field.decrypt_text(value, context)
			end
		end
	end

	if defined?(Rails::Railtie)
		class Initializer < Rails::Railtie
			initializer "active_enquo.root_key" do |app|
				if app
					if root_key = app.credentials.active_enquo.root_key
						ActiveEnquo.root_key = Enquo::RootKey::Static.new(root_key)
					else
						Rails.warn "Could not initialize ActiveEnquo, as no active_enquo.root_key credential was found for this environment"
					end
				end
			end
		end
	end
end

ActiveSupport.on_load(:active_record) do
	::ActiveRecord::Base.send :include, ActiveEnquo::ActiveRecord::ModelExtension

	::ActiveRecord::ConnectionAdapters::Table.include ActiveEnquo::ActiveRecord::TableDefinitionExtension
	::ActiveRecord::ConnectionAdapters::TableDefinition.include ActiveEnquo::ActiveRecord::TableDefinitionExtension

	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend ActiveEnquo::Postgres::ConnectionAdapter

	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:enquo_bigint] = { name: "enquo_bigint" }
	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:enquo_date]   = { name: "enquo_date" }
	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:enquo_text]   = { name: "enquo_text" }
end
