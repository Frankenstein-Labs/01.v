# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkerSessionStateSetter, feature_category: :system_access do
  include_examples 'perform with session state' do
    let(:worker) do
      Class.new do
        def self.name
          'Gitlab::TestWorker'
        end

        include ApplicationWorker
        include WorkerSessionStateSetter
      end
    end
  end
end
