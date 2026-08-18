# frozen_string_literal: true

module Ci
  class JobAiEntity < ::Ci::JobEntity
    include Gitlab::Llm::Chain::Concerns::JobLoggable

    expose :job_log do |_job, options|
      job_log&.last(options[:content_limit])
    end
  end
end
