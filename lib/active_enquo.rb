require "active_record/connection_adapters/postgresql_adapter"
require "active_support/lazy_load_hooks"

require "enquo"

module ActiveEnquo
	def self.root_key=(k)
		unless k.is_a?(String) && k.encoding == Encoding::BINARY && k.bytesize == 32
			raise ArgumentError, "The ActiveEnquo root key must be a 32 byte binary string"
		end

		@crypto = Enquo::Crypto.new(k)
	end

	def self.crypto
		if @crypto.nil?
			raise RuntimeError, "The ActiveEnquo root key must be set before calling ActiveEnquo.crypto"
		end

		@crypto
	end

	module ActiveRecord
		module ModelExtension
			extend ActiveSupport::Concern

			def _read_attribute(attr_name, &block)
				t = self.class.attribute_types[attr_name]
				if t.is_a?(::ActiveEnquo::Type)
					relation = self.class.arel_table.name
					value = @attributes.fetch_value(attr_name, &block)
					field = ::ActiveEnquo.crypto.field(relation, attr_name)
					begin
						t.decrypt(value, @attributes.fetch_value(@primary_key).to_s, field)
					rescue RuntimeError
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
					field = ::ActiveEnquo.crypto.field(relation, attr_name)
					db_value = t.encrypt(value, @attributes.fetch_value(@primary_key).to_s, field)
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
						field = ::ActiveEnquo.crypto.field(relation, attr_name)
						t.encrypt(value, "", field)
					else
						raise ArgumentError, "Cannot produce encrypted value on a non-enquo attribute '#{attr_name}'"
					end
				end
			end
		end
	end

	module Postgres
		module ConnectionAdapter
			def initialize_type_map(m = type_map)
				m.register_type "enquo_bigint", ActiveEnquo::Type::Bigint.new

				super
			end
		end
	end

	class Type < ::ActiveRecord::Type::Value
		class Bigint < Type
			def type
				:enquo_bigint
			end

			def encrypt(value, context, field)
				field.encrypt_i64(value, context)
			end

			def decrypt(value, context, field)
				field.decrypt_i64(value, context)
			end
		end
	end
end

ActiveSupport.on_load(:active_record) do
	::ActiveRecord::Base.send :include, ActiveEnquo::ActiveRecord::ModelExtension

	::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend ActiveEnquo::Postgres::ConnectionAdapter
#	::ActiveRecord::Type.register(:enquo_bigint, ActiveEnquo::Type::Bigint, adapter: :postgresql)

	unless ActiveRecord::VERSION::MAJOR == 7
		::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:enquo_bigint] = {}
	end
end
