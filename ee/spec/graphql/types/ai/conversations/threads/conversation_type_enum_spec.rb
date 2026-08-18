# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiConversationsThreadsConversationType'], feature_category: :duo_chat do
  let(:expected_values) { %w[DUO_CHAT_LEGACY DUO_CODE_REVIEW DUO_QUICK_CHAT DUO_CHAT] }

  subject { described_class.values.keys }

  it { is_expected.to match_array(expected_values) }
end
