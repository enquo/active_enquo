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
		module QueryFilterMangler
			class Ciphertext < String
			end
			private_constant :Ciphertext

			private

			def mangle_query_filter(a)
				args = a.first
				if args.is_a?(Hash)
					args.keys.each do |attr|
						next unless enquo_attr?(attr)

						if args[attr].is_a?(Array)
							args[attr] = args[attr].map { |v| maybe_enquo(attr, v) }
						elsif args[attr].is_a?(Range)
							r = args[attr]
							args[attr] = if r.exclude_end?
								if r.begin.nil?
									...maybe_enquo(attr, r.end)
								elsif r.end.nil?
									(maybe_enquo(attr.r.begin)...)
								else
									maybe_enquo(attr.r.begin)...maybe_enquo(attr, r.end)
								end
							else
								if r.begin.nil?
									..maybe_enquo(attr, r.end)
								elsif r.end.nil?
									maybe_enquo(attr.r.begin)..
								else
									maybe_enquo(attr.r.begin)..maybe_enquo(attr, r.end)
								end
							end
						else
							args[attr] = maybe_enquo(attr, args[attr])
						end
					end
				end
			end

			def maybe_enquo(attr, v)
				if v.nil? || v.is_a?(Ciphertext) || v.is_a?(::ActiveRecord::StatementCache::Substitute)
					v
				else
					Ciphertext.new(enquo(attr, v))
				end
			end
		end

		module BaseExtension
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
					db_value = t.encrypt(value, @attributes.fetch_value(@primary_key).to_s, field, **attr_opts)
					@attributes.write_from_user(attr_name, db_value)
				else
					super
				end
			end

			module ClassMethods
				include QueryFilterMangler

				def find_by(*a)
					mangle_query_filter(a)
					super
				end

				def enquo(attr_name, value_or_meta_id, maybe_value = nil)
					meta_id, value = if value_or_meta_id.is_a?(Symbol)
						[value_or_meta_id, maybe_value]
					else
						[nil, value_or_meta_id]
					end

					t = self.attribute_types[attr_name.to_s]
					if t.is_a?(::ActiveEnquo::Type)
						relation = self.arel_table.name
						field = ::ActiveEnquo.root.field(relation, attr_name)
						if meta_id.nil?
							t.encrypt(value, "", field, enable_reduced_security_operations: true)
						else
							t.encrypt_metadata_value(meta_id, value, field)
						end
					else
						raise ArgumentError, "Cannot produce encrypted value on a non-enquo attribute '#{attr_name}'"
					end
				end

				def unenquo(attr_name, value, ctx)
					t = self.attribute_types[attr_name.to_s]
					if t.is_a?(::ActiveEnquo::Type)
						relation = self.arel_table.name
						field = ::ActiveEnquo.root.field(relation, attr_name)
						begin
							t.decrypt(value, ctx, field)
						rescue Enquo::Error
							t.decrypt(value, "", field)
						end
					else
						raise ArgumentError, "Cannot decrypt value on a non-enquo attribute '#{attr_name}'"
					end
				end

				def enquo_attr?(attr_name)
					self.attribute_types[attr_name.to_s].is_a?(::ActiveEnquo::Type)
				end

				def enquo_attr(attr_name, opts)
					if opts.key?(:default)
						default_value = opts.delete(:default)
						after_initialize do
							next if persisted?
							next unless self.send(attr_name).nil?
							self.send(:"#{attr_name}=", default_value.duplicable? ? default_value.dup : default_value)
						end
					end

					enquo_attribute_options[attr_name] = @enquo_attribute_options[attr_name].merge(opts)
				end

				def enquo_attribute_options
					@enquo_attribute_options ||= Hash.new({})
				end

				def enquo_encrypt_columns(column_map, batch_size: 10_000)
					plaintext_columns = column_map.keys
					relation = self.arel_table.name
					in_progress = true
					self.reset_column_information

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
										t = self.attribute_types[ct_col.to_s]
										db_value = t.encrypt(row[pt_col.to_s], row[self.primary_key].to_s, field, **attr_opts)

										[ct_col, db_value]
									end]

									self.where(self.primary_key => row[self.primary_key]).update_all(values)
								end
							end
						end
					end
				end
			end
		end

		module TableDefinitionExtension
			def enquo_boolean(name, **options)
				column(name, :enquo_boolean, **options)
			end

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

		module RelationExtension
			include QueryFilterMangler
			extend ActiveSupport::Concern

			def where(*a)
				mangle_query_filter(a)
				super
			end

			def exists?(*a)
				mangle_query_filter(a)
				super
			end

		end
	end

	module Postgres
		module ConnectionAdapter
			def initialize_type_map(m = type_map)
				m.register_type "enquo_boolean", ActiveEnquo::Type::Boolean.new
				m.register_type "enquo_bigint", ActiveEnquo::Type::Bigint.new
				m.register_type "enquo_date", ActiveEnquo::Type::Date.new
				m.register_type "enquo_text", ActiveEnquo::Type::Text.new

				super
			end
		end
	end

	class Type < ::ActiveRecord::Type::Value
		class Boolean < Type
			def type
				:enquo_boolean
			end

			def encrypt(value, context, field, enable_reduced_security_operations: false, no_query: false)
				if value.nil? || value.is_a?(::ActiveRecord::StatementCache::Substitute)
					value
				else
					field.encrypt_boolean(value, context, safety: enable_reduced_security_operations ? :unsafe : true, no_query: no_query)
				end
			end

			def decrypt(value, context, field)
				field.decrypt_boolean(value, context)
			end
		end

		class Bigint < Type
			def type
				:enquo_bigint
			end

			def encrypt(value, context, field, enable_reduced_security_operations: false, no_query: false)
				if value.nil? || value.is_a?(::ActiveRecord::StatementCache::Substitute)
					value
				else
					field.encrypt_i64(value, context, safety: enable_reduced_security_operations ? :unsafe : true, no_query: no_query)
				end
			end

			def decrypt(value, context, field)
				field.decrypt_i64(value, context)
			end
		end

		class Date < Type
			def type
				:enquo_date
			end

			def encrypt(value, context, field, enable_reduced_security_operations: false, no_query: false)
				value = cast_to_date(value)
				if value.nil?
					value
				else
					field.encrypt_date(value, context, safety: enable_reduced_security_operations ? :unsafe : true, no_query: no_query)
				end
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
				elsif value.nil? || (value.respond_to?(:empty?) && value.empty?) || value.is_a?(::ActiveRecord::StatementCache::Substitute)
					nil
				else
					Time.parse(value.to_s).to_date
				end
			end
		end

		class Text < Type
			def type
				:enquo_text
			end

			def encrypt(value, context, field, enable_reduced_security_operations: false, no_query: false, enable_ordering: false)
				if enable_ordering && !enable_reduced_security_operations
					raise ArgumentError, "Cannot enable ordering on an Enquo attribute unless Reduced Security Operations are enabled"
				end

				if value.nil? || value.is_a?(::ActiveRecord::StatementCache::Substitute)
					value
				else
					field.encrypt_text(value.respond_to?(:encode) ? value.encode("UTF-8") : value, context, safety: enable_reduced_security_operations ? :unsafe : true, no_query: no_query, order_prefix_length: enable_ordering ? 8 : nil)
				end
			end

			def encrypt_metadata_value(name, value, field)
				case name
				when :length
					field.encrypt_text_length_query(value)
				else
					raise ArgumentError, "Unknown metadata name for Text field: #{name.inspect}"
				end
			end

			def decrypt(value, context, field)
				if value.nil?
					nil
				else
					field.decrypt_text(value, context)
				end
			end
		end
	end

	if defined?(Rails::Railtie)
		class Initializer < Rails::Railtie
			initializer "active_enquo.root_key" do |app|
				if app
					if app.credentials
						if app.credentials.active_enquo
							if root_key = app.credentials.active_enquo.root_key
								ActiveEnquo.root_key = Enquo::RootKey::Static.new(root_key)
							else
								Rails.logger.warn "Could not initialize ActiveEnquo, as no active_enquo.root_key credential was found for this environment"
							end
						else
							Rails.logger.warn "Could not initialize ActiveEnquo, as no active_enquo credentials were found for this environment"
						end
					else
						Rails.logger.warn "Could not initialize ActiveEnquo, as no credentials were found for this environment"
					end
				else
					Rails.logger.warn "Could not initialize ActiveEnquo, as no app was found for this environment"
				end
			end
		end
	end
end

ActiveSupport.on_load(:active_record) do
	::ActiveRecord::Relation.prepend ActiveEnquo::ActiveRecord::RelationExtension
	::ActiveRecord::Base.include ActiveEnquo::ActiveRecord::BaseExtension

	::ActiveRecord::ConnectionAdapters::Table.include ActiveEnquo::ActiveRecord::TableDefinitionExtension
	::ActiveRecord::ConnectionAdapters::TableDefinition.include ActiveEnquo::ActiveRecord::TableDefinitionExtension

	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend ActiveEnquo::Postgres::ConnectionAdapter

	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:enquo_boolean] = { name: "enquo_boolean" }
	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:enquo_bigint] = { name: "enquo_bigint" }
	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:enquo_date]   = { name: "enquo_date" }
	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:enquo_text]   = { name: "enquo_text" }
end
