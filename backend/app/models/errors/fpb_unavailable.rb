module Errors
  # The FPB portal did not answer, or answered something we cannot read
  class FpbUnavailable < StandardError; end
end
