module Errors
  # An action that is not possible in the record's current state
  class InvalidState < StandardError; end
end
