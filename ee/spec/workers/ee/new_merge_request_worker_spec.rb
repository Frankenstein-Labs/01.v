# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NewMergeRequestWorker, feature_category: :code_review_workflow do
  include_examples 'perform with session state' do
    let(:worker) { described_class }
  end
end
