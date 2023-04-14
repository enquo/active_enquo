require_relative '../spec_helper'
require 'active_enquo'

require_relative "../support/models/bigint"

def bind_param(value)
	ActiveRecord::Relation::QueryAttribute.new(nil, value, ActiveRecord::Type::Value.new)
end

shared_examples "an ORE-encrypted bigint" do |model, value, unsafe: false, no_query: false|
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

	it "is a v1 ciphertext" do
		expect(json_value).to have_key(:v1)
	end

	it "has an AES v1 ciphertext" do
		expect(json_value[:v1]).to have_key(:a)
	end

	unless no_query
		it "has an ORE v1 ciphertext" do
			expect(json_value[:v1]).to have_key(:o)
		end
	end

	it "has a key ID" do
		expect(json_value[:v1]).to have_key(:k)
		expect(json_value[:v1][:k]).to match([a_value_between(0, 255)] * 4)
	end

	let(:aes) { json_value[:v1][:a] }

	it "has a 96 bit IV" do
		expect(aes[:iv]).to match([a_value_between(0, 255)] * 12)
	end

	it "has a bytestring ciphertext" do
		expect(aes[:ct].length).to satisfy { |l| l >= 8 }
		expect(aes[:ct]).to all be_between(0, 255)
	end

	let(:ore) { json_value[:v1][:o] }

	if no_query
		it "has no ORE ciphertext" do
			expect(ore).to be_nil
		end
	else
		if unsafe
			it "has a bytestring left ORE ciphertext" do
				expect(ore[:l].length).to eq(136)
				expect(ore[:l]).to all be_between(0, 255)
			end
		else
			it "has no left ORE ciphertext" do
				expect(ore[:l]).to be_nil
			end
		end

		it "has a bytestring right ORE ciphertext" do
			expect(ore[:r].length).to be_between(420, 460)
			expect(ore[:r]).to all be_between(0, 255)
		end
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
				it_behaves_like "an ORE-encrypted bigint", Bigint, v
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

	context "into sortable_bigint" do
		{
			"zero" => 0,
			"a small positive integer" => 42,
			"a small negative integer" => -42,
			"a large positive integer" => 2**42,
			"a large negative integer" => -2**42,
		}.each do |desc, v|
			context "storing #{desc}" do
				it_behaves_like "an ORE-encrypted bigint", SortableBigint, v, unsafe: true
			end
		end
	end

	context "into unqueryable_bigint" do
		{
			"zero" => 0,
			"a small positive integer" => 42,
			"a small negative integer" => -42,
			"a large positive integer" => 2**42,
			"a large negative integer" => -2**42,
		}.each do |desc, v|
			context "storing #{desc}" do
				it_behaves_like "an ORE-encrypted bigint", UnqueryableBigint, v, no_query: true
			end
		end
	end
end
