require_relative './utils/utils'
using StringColors

if ARGV.count != 1
  abort "⛔️ Pass the count of latest versions to print.".red
end

TAG_PREFIX = 'Geko/Release'.freeze
VERSIONS_COUNT = ARGV[0].to_i.freeze

tags_output = `git ls-remote --tags --quiet | grep -o '#{TAG_PREFIX}/\\d\\+\\.\\d\\+\\.\\d\\+$' | sed s.#{TAG_PREFIX}/.. | sort -rV`
versions = tags_output.lines.map(&:chomp)[0..(VERSIONS_COUNT - 1)]
puts versions
