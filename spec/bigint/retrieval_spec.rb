require_relative '../spec_helper'
require 'active_enquo'

require_relative "../support/models/bigint"

describe "record retrieval" do
	[Bigint, SortableBigint, UnqueryableBigint].each do |model|
		context "from #{model}" do
			before(:all) do
				model.create!([
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
				expect(model.where(notes: "zero").first.value).to eq(0)
				expect(model.where(notes: "medium positive").first.value).to eq(420)
				expect(model.where(notes: "large negative").first.value).to eq(-2**42)
			end

			if model == UnqueryableBigint
				it "cannot be queried" do
					expect { model.where(value: model.enquo(:value, 0)).first }.to raise_error(ActiveRecord::StatementInvalid)
				end
			else
				it "retrieves and decrypts a single record" do
					[0, 42, 420, 2**42, -42, -420, -2**42].each do |i|
						expect(model.where(value: model.enquo(:value, i)).first.value).to eq(i)
					end
				end
			end
		end
	end
end
