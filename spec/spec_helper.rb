require 'bundler'
Bundler.setup(:default, :development)
require 'rspec/core'
require 'rspec/mocks'

require "active_record"
require_relative "./support/migrations/create_bigints"
require_relative "./support/migrations/create_dates"
require_relative "./support/migrations/create_texts"

require 'simplecov'
SimpleCov.start do
	enable_coverage :branch
	primary_coverage :branch
	add_filter('spec')
end

class ListIncompletelyCoveredFiles
	def format(result)
		incompletes = result.files.select { |f| f.covered_percent < 100 }

		unless incompletes.empty?
			puts
			puts "Files with incomplete test coverage:"
			incompletes.each do |f|
				printf "    %2.01f%%    %s\n", f.covered_percent, f.filename
			end
			puts; puts
		end
	end
end

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
	SimpleCov::Formatter::HTMLFormatter,
	ListIncompletelyCoveredFiles
])

RSpec.configure do |config|
	config.order = :random
	config.fail_fast = !!ENV["RSPEC_CONFIG_FAIL_FAST"]
	config.full_backtrace = !!ENV["RSPEC_CONFIG_FULL_BACKTRACE"]

	config.expect_with :rspec do |c|
		c.syntax = :expect
	end

	config.before(:suite) do
		ActiveRecord::Base.establish_connection(adapter: 'postgresql')

		[
			CreateBigints, CreateSortableBigints, CreateUnqueryableBigints,
			CreateEnDates, CreateSortableDates, CreateUnqueryableDates,
			CreateTexts, CreateUnqueryableTexts,
		].each do |migration|
			migration.migrate(:down) rescue nil
			migration.migrate(:up)
		end

		::ActiveEnquo.root_key = ::ActiveEnquo::RootKey::Static.new(SecureRandom.bytes(32))
	end
end
