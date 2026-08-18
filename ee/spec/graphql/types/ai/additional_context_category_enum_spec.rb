# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAdditionalContextCategory'], feature_category: :duo_chat do
  it 'exposes all additional context categories' do
    expect(described_class.values.keys).to match_array(%w[FILE SNIPPET MERGE_REQUEST ISSUE DEPENDENCY LOCAL_GIT
      TERMINAL REPOSITORY DIRECTORY USER_RULE AGENT_USER_ENVIRONMENT])
  end
end
