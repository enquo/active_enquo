require_relative '../spec_helper'
require 'active_enquo'

require_relative "../support/models/bigint"

def bind_param(value)
	ActiveRecord::Relation::QueryAttribute.new(nil, value, ActiveRecord::Type::Value.new)
end

shared_examples "an ORE-encrypted value" do |model, value|
	let(:record) { model.new(value: value) }
	let(:db_value) do
		record.save!
		model.connection.select_one("SELECT value FROM #{model.arel_table.name} WHERE id=$1", nil, [bind_param(record.id)])["value"]
	end

	it "succeeds" do
		expect { record.save! }.to_not raise_error
	end

	it "stores the value as a JSON document" do
		expect { JSON.parse(db_value) }.to_not raise_error
	end

	let(:json_value) { JSON.parse(db_value, symbolize_names: true) }

	it "is an OREv1" do
		expect(json_value).to have_key(:ORE64v1)
	end

	let(:ore64v1) { json_value[:ORE64v1] }

	it "has a 96 bit IV" do
		expect(ore64v1[:iv]).to match([a_value_between(0, 255)] * 12)
	end

	it "has a bytestring ciphertext" do
		expect(ore64v1[:ct].length).to satisfy { |l| l >= 8 }
		expect(ore64v1[:ct]).to all be_between(0, 255)
	end

	it "has a bytestring ORE ciphertext" do
		expect(ore64v1[:ore].length).to satisfy { |l| l >= 200 }
		expect(ore64v1[:ore]).to all be_between(0, 255)
	end
end

describe "record insertion" do
	context "into bigint" do
		{
			"zero" => 0,
			"a small positive integer" => 42,
			"a small negative integer" => -42,
			"a large positive integer" => 2**42,
			"a large negative integer" => -2**42,
		}.each do |desc, v|
			context "storing #{desc}" do
				it_behaves_like "an ORE-encrypted value", Bigint, v
			end
		end

		{
			"a slightly too large positive integer" => 2**63,
			"an excessively large positive integer" => 2**420,
			"a slightly too large (small?) negative integer" => -2**63 - 1,
			"an excessively large negative integer" => -2**420,
		}.each do |desc, v|
			context "storing #{desc}" do
				let(:model) { Bigint }
				let(:value) { v }

				it "explodes" do
					expect { Bigint.new(value: v).save! }.to raise_error(RangeError)
				end
			end
		end

		{
			"a float" => 4.2,
			"a string" => "ohai!",
		}.each do |desc, v|
			context "storing #{desc}" do
				let(:model) { Bigint }
				let(:value) { v }

				it "explodes" do
					expect { Bigint.new(value: v).save! }.to raise_error(ArgumentError)
				end
			end
		end
	end
end