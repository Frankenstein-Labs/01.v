# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessageDismissal, feature_category: :acquisition do
  describe 'associations' do
    it { is_expected.to belong_to(:targeted_message).required }
    it { is_expected.to belong_to(:user).required }
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    subject { build(:targeted_message_dismissal) }

    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:targeted_message_id, :namespace_id) }
  end
end
