require_relative '../spec_helper'
require 'active_enquo'

require_relative "../support/models/bigint"

describe "record retrieval" do
	context "from bigint" do
		before(:all) do
			Bigint.create!([
				{ value: 0, notes: "zero" },
				{ value: 42, notes: "small positive" },
				{ value: 420, notes: "medium positive" },
				{ value: 2**42, notes: "large positive" },
				{ value: -42, notes: "small negative" },
				{ value: -420, notes: "medium negative" },
				{ value: -2**42, notes: "large negative" },
			])
		end

		it "decrypts a single record" do
			expect(Bigint.where(notes: "zero").first.value).to eq(0)
			expect(Bigint.where(notes: "medium positive").first.value).to eq(420)
			expect(Bigint.where(notes: "large negative").first.value).to eq(-2**42)
		end

		it "retrieves and decrypts a single record" do
			[0, 42, 420, 2**42, -42, -420, -2**42].each do |i|
				expect(Bigint.where(value: Bigint.enquo(:value, i)).first.value).to eq(i)
			end
		end
	end
end
