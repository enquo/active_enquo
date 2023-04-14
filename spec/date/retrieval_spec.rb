require_relative '../spec_helper'
require 'active_enquo'

require_relative "../support/models/date"

describe "record retrieval" do
	[EnDate, SortableDate, UnqueryableDate].each do |model|
		context "from #{model}" do
			before(:all) do
				model.delete_all
				model.create!([
					{ notes: "around now", value: Date.new(2022, 9, 1) },
					{ notes: "a little while ago", value: Date.new(1970, 1, 1) },
					{ notes: "a long time ago", value: Date.new(1492, 12, 17) },
					{ notes: "a *really* long time ago", value: Date.new(-4000, 1, 1) },
					{ notes: "not long enough in the future", value: Date.new(2038, 1, 19) },
					{ notes: "a long time in the future", value: Date.new(2106, 2, 7) },
					{ notes: "a *really* long time in the future", value: Date.new(4096, 1, 1) },
				])
			end

			it "decrypts a single record" do
				expect(model.where(notes: "around now").first.value).to eq(Date.new(2022, 9, 1))
				expect(model.where(notes: "a *really* long time ago").first.value).to eq(Date.new(-4000, 1, 1))
				expect(model.where(notes: "a long time in the future").first.value).to eq(Date.new(2106, 2, 7))
			end

			if model == UnqueryableDate
				it "cannot be queried" do
					expect { model.where(value: Date.new(1970, 1, 1)).first }.to raise_error(ActiveRecord::StatementInvalid)
				end
			else
				it "retrieves and decrypts a single record" do
					[
						Date.new(2022, 9, 1),
						Date.new(1970, 1, 1),
						Date.new(1492, 12, 17),
						Date.new(-4000, 1, 1),
						Date.new(2038, 1, 19),
						Date.new(2106, 2, 7),
						Date.new(4096, 1, 1),
					].each do |i|
						expect(model.where(value: i).first.value).to eq(i)
					end
				end

				it "queries correctly" do
					expect(model.where(value: ...Date.new(2000, 1, 1)).count).to eq(3)
				end
			end
		end
	end
end
