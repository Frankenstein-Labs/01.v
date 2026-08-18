# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::GroupSecurityExclusion, feature_category: :secret_detection, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:scanner) }
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_length_of(:value).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }
    it { is_expected.to allow_value(true, false).for(:active) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:scanner).with_values([:secret_push_protection]) }
    it { is_expected.to define_enum_for(:type).with_values([:path, :regex_pattern, :raw_value, :rule]) }
  end

  context 'with loose foreign key on group_security_exclusions.group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:group_security_exclusion, group: parent) }
    end
  end
end
