# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::SavedReply, feature_category: :code_review_workflow do
  let_it_be(:saved_reply) { create(:project_saved_reply) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to([:project_id]) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:content).is_at_most(10000) }
  end
end
