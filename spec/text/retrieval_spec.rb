require_relative '../spec_helper'
require 'active_enquo'

require_relative "../support/models/text"

describe "record retrieval" do
	TEST_DATA = {
		"empty"  => "",
		"short"  => "Hello, Enquo!",
		"medium" => "The quick brown fox jumps over the lazy dog",
		"long"   => (["Hello, Enquo!"] * 100).join("\n"),
	}

	[Text, UnqueryableText].each do |model|
		context "from #{model}" do
			before(:all) do
				model.create!(TEST_DATA.map { |k, v| { value: v, notes: k } })
			end

			TEST_DATA.each do |k, v|
				it "decrypts a single #{k} record" do
					expect(model.where(notes: k).first.value).to eq(v)
				end
			end

			if model == UnqueryableText
				it "cannot be queried" do
					expect { model.where(value: model.enquo(:value, "")).first }.to raise_error(ActiveRecord::StatementInvalid)
				end
			else
				TEST_DATA.each do |k, v|
					it "retrieves and decrypts a single #{k} record" do
						expect(model.where(value: model.enquo(:value, v)).first.value).to eq(v)
					end
				end
			end
		end
	end
end
