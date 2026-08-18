# frozen_string_literal: true

module Gitlab
  module Cd
    class Logger < ::Gitlab::JsonLogger
      def self.file_name_noext
        'cd'
      end
    end
  end
end
