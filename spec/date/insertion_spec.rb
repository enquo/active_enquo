require_relative '../spec_helper'
require 'active_enquo'
require "date"

require_relative "../support/models/date"

def bind_param(value)
	ActiveRecord::Relation::QueryAttribute.new(nil, value, ActiveRecord::Type::Value.new)
end

shared_examples "an ORE-encrypted date" do |model, value, unsafe: false, no_query: false|
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

	let(:ore_year) { json_value[:v1][:y] }
	let(:ore_month) { json_value[:v1][:m] }
	let(:ore_day) { json_value[:v1][:d] }

	if no_query
		it "has no ORE ciphertexts" do
			expect(ore_year).to be_nil
			expect(ore_month).to be_nil
			expect(ore_day).to be_nil
		end
	else
		if unsafe
			it "has bytestring left ORE ciphertexts" do
				expect(ore_year[:l].length).to eq(34)
				expect(ore_year[:l]).to all be_between(0, 255)
				expect(ore_month[:l].length).to eq(17)
				expect(ore_month[:l]).to all be_between(0, 255)
				expect(ore_day[:l].length).to eq(17)
				expect(ore_day[:l]).to all be_between(0, 255)
			end
		else
			it "has no left ORE ciphertexts" do
				expect(ore_year[:l]).to be_nil
				expect(ore_month[:l]).to be_nil
				expect(ore_day[:l]).to be_nil
			end
		end

		it "has bytestring right ORE ciphertexts" do
			expect(ore_year[:r].length).to be_between(110, 140)
			expect(ore_year[:r]).to all be_between(0, 255)
			expect(ore_month[:r].length).to be_between(20, 30)
			expect(ore_month[:r]).to all be_between(0, 255)
			expect(ore_day[:r].length).to be_between(20, 30)
			expect(ore_day[:r]).to all be_between(0, 255)
		end
	end
end

describe "record insertion" do
	context "into date" do
		{
			"around now" => Date.new(2022, 9, 1),
			"a little while ago" => Date.new(1970, 1, 1),
			"a long time ago" => Date.new(1492, 12, 17),
			"a *really* long time ago" => Date.new(-4000, 1, 1),
			"not long enough in the future" => Date.new(2038, 1, 19),
			"a long time in the future" => Date.new(2106, 2, 7),
			"a *really* long time in the future" => Date.new(4096, 1, 1),
		}.each do |desc, v|
			context "storing #{desc}" do
				it_behaves_like "an ORE-encrypted date", EnDate, v
			end
		end

		{
			"too long ago" => Date.new(-33_000, 1, 1),
			"too far in the future" => Date.new(33_000, 1, 1),
		}.each do |desc, v|
			context "storing #{desc}" do
				let(:model) { EnDate }
				let(:value) { v }

				it "explodes" do
					expect { EnDate.new(value: v).save! }.to raise_error(RangeError)
				end
			end
		end

		{
			"a float" => 4.2,
			"a string" => "ohai!",
		}.each do |desc, v|
			context "storing #{desc}" do
				let(:model) { EnDate }
				let(:value) { v }

				it "explodes" do
					expect { EnDate.new(value: v).save! }.to raise_error(ArgumentError)
				end
			end
		end
	end

	context "into sortable_date" do
		{
			"around now" => Date.new(2022, 9, 1),
			"a little while ago" => Date.new(1970, 1, 1),
			"a long time ago" => Date.new(1492, 12, 17),
			"a *really* long time ago" => Date.new(-4000, 1, 1),
			"not long enough in the future" => Date.new(2038, 1, 19),
			"a long time in the future" => Date.new(2106, 2, 7),
			"a *really* long time in the future" => Date.new(4096, 1, 1),
		}.each do |desc, v|
			context "storing #{desc}" do
				it_behaves_like "an ORE-encrypted date", SortableDate, v, unsafe: true
			end
		end
	end

	context "into unqueryable_date" do
		{
			"around now" => Date.new(2022, 9, 1),
			"a little while ago" => Date.new(1970, 1, 1),
			"a long time ago" => Date.new(1492, 12, 17),
			"a *really* long time ago" => Date.new(-4000, 1, 1),
			"not long enough in the future" => Date.new(2038, 1, 19),
			"a long time in the future" => Date.new(2106, 2, 7),
			"a *really* long time in the future" => Date.new(4096, 1, 1),
		}.each do |desc, v|
			context "storing #{desc}" do
				it_behaves_like "an ORE-encrypted date", UnqueryableDate, v, no_query: true
			end
		end
	end
end

