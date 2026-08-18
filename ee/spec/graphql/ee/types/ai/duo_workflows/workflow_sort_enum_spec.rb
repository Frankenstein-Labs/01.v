# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DuoWorkflowsWorkflowSort'], feature_category: :duo_agent_platform do
  it_behaves_like "sort enum type with additional fields" do
    let(:additional_values) { %w[STATUS_ASC STATUS_DESC] }
  end
end
