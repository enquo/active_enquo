require_relative '../spec_helper'
require 'active_enquo'

require_relative "../support/models/text"

def bind_param(value)
	ActiveRecord::Relation::QueryAttribute.new(nil, value, ActiveRecord::Type::Value.new)
end

shared_examples "an ORE-encrypted text" do |model, value, unsafe: false, no_query: false|
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

	it "has an AES ciphertext" do
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

	if no_query
		it "has no equality ciphertext" do
			expect(json_value[:v1][:e]).to be_nil
		end
	else
		it "has an equality ciphertext" do
			expect(json_value[:v1]).to have_key(:e)
		end

		let(:eqc) { json_value[:v1][:e] }

		if unsafe
			it "has a bytestring left equality ciphertext" do
				expect(eqc[:l].length).to eq(136)
				expect(eqc[:l]).to all be_between(0, 255)
			end

			it "has a numeric hash code" do
				expect(json_value[:v1]).to have_key(:h)
				expect(json_value[:v1][:h]).to be_between(0, 2**32-1)
			end
		else
			it "has no left equality ciphertext" do
				expect(eqc[:l]).to be_nil
			end
		end

		it "has a bytestring right equality ciphertext" do
			expect(eqc[:r].length).to eq(48)
			expect(eqc[:r]).to all be_between(0, 255)
		end
	end
end

describe "record insertion" do
	context "into text" do
		{
			"empty"  => "",
			"short"  => "Hello, Enquo!",
			"medium" => "The quick brown fox jumps over the lazy dog",
			"long"   => (["Hello, Enquo!"] * 100).join("\n"),
		}.each do |desc, v|
			context "storing #{desc}" do
				it_behaves_like "an ORE-encrypted text", Text, v
			end
		end

		{
			"a float" => 4.2,
			"an integer" => 42,
			"non-UTF8 string" => "\0\0\0\0",
			"invalid UTF8 string" => "\0\0\0\0".force_encoding("UTF-8"),
			"a random object" => Object.new,
		}.each do |desc, v|
			context "storing #{desc}" do
				let(:model) { Text }
				let(:value) { v }

				it "explodes" do
					expect { Text.new(value: v).save! }.to raise_error(ArgumentError)
				end
			end
		end
	end

	context "into unqueryable_text" do
		{
			"empty"  => "",
			"short"  => "Hello, Enquo!",
			"medium" => "The quick brown fox jumps over the lazy dog",
			"long"   => (["Hello, Enquo!"] * 100).join("\n"),
		}.each do |desc, v|
			context "storing #{desc}" do
				it_behaves_like "an ORE-encrypted text", UnqueryableText, v, no_query: true
			end
		end
	end
end
