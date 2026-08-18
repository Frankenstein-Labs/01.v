# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Milestones::CreateService, feature_category: :team_planning do
  let_it_be(:params) { { title: 'New Milestone', description: 'Description' } }
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(container, user, params) }

  describe '#execute' do
    context 'on group milestones' do
      let_it_be(:container) { create(:group, maintainers: user) }

      context 'when group webhooks are available' do
        before do
          stub_licensed_features(group_webhooks: true)
        end

        context 'when group has active milestone hooks' do
          before do
            allow(container).to receive(:has_active_hooks?).with(:milestone_hooks).and_return(true)
          end

          it_behaves_like 'creates the milestone', with_hooks: true, with_event: false
        end

        context 'when group has no active milestone hooks' do
          it_behaves_like 'creates the milestone', with_hooks: false, with_event: false
        end
      end

      context 'when group webhooks are not available' do
        it_behaves_like 'creates the milestone', with_hooks: false, with_event: false
      end
    end
  end
end
