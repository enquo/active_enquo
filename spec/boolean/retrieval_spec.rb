require_relative '../spec_helper'
require 'active_enquo'

require_relative "../support/models/boolean"

describe "record retrieval" do
	[Boolean, SortableBoolean, UnqueryableBoolean].each do |model|
		context "from #{model}" do
			before(:all) do
				model.create!([
					{ value: true, notes: "true" },
					{ value: false, notes: "false" },
				])
			end

			it "decrypts a single record" do
				expect(model.where(notes: "true").first.value).to eq(true)
				expect(model.where(notes: "false").first.value).to eq(false)
			end

			if model == UnqueryableBoolean
				it "cannot be queried" do
					expect { model.where(value: model.enquo(:value, false)).first }.to raise_error(ActiveRecord::StatementInvalid)
				end
			else
				it "retrieves and decrypts a single record" do
					[true, false].each do |i|
						expect(model.where(value: model.enquo(:value, i)).first.value).to eq(i)
					end
				end
			end
		end
	end
end
