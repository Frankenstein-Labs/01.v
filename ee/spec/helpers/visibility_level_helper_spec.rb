# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VisibilityLevelHelper, feature_category: :system_access do
  describe '#visibility_level_description' do
    context 'with Group' do
      let(:group) { build_stubbed(:group) }

      subject(:description) { visibility_level_description(Gitlab::VisibilityLevel::PUBLIC, group) }

      shared_examples_for 'default group description' do
        it { is_expected.to eq('The group and any public projects can be viewed without any authentication.') }
      end

      it_behaves_like 'default group description'

      context 'when gitlab_com_subscriptions SaaS feature is available' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        it 'returns updated description for public visibility option in group general settings' do
          expect(description).to match(
            'The group, any public projects, and any of their members, issues, and merge requests can be viewed ' \
              'without authentication.'
          )
        end

        context 'when group is a new record' do
          let(:group) { build(:group) }

          it_behaves_like 'default group description'
        end
      end
    end
  end
end
