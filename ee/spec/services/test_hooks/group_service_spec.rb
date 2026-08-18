# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TestHooks::GroupService, feature_category: :webhooks do
  include AfterNextHelpers

  let(:current_user) { create(:user) }

  describe '#execute' do
    let(:sample_data) { { data: 'sample' } }
    let(:success_result) { { status: :success, http_status: 200, message: 'ok' } }

    context 'when hook is for a group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, :repository, group: group) }

      let(:hook) { create(:group_hook, group: group) }
      let(:trigger) { 'not_implemented_events' }
      let(:service) { described_class.new(hook, current_user, trigger) }

      context 'when the group is IP restricted' do
        before do
          allow_next_instance_of(Gitlab::IpRestriction::Enforcer) do |enforcer|
            allow(enforcer).to receive(:allows_current_ip?).and_return(false)
          end
        end

        it 'returns a forbidden error', :aggregate_failures do
          result = service.execute

          expect(result).to be_error
          expect(result.reason).to eq(:forbidden)
          expect(result.message).to eq('Group access restricted by IP address.')
        end
      end

      context 'for project_hooks' do
        let(:trigger) { 'project_events' }
        let(:trigger_key) { :project_hooks }

        it 'executes hook' do
          allow_next(Gitlab::HookData::ProjectBuilder).to receive(:build).and_return(sample_data)

          expect(hook).to receive(:execute).with(sample_data, trigger_key, force: true).and_return(success_result)
          expect(service.execute).to include(success_result)
        end
      end
    end

    context 'when hook is for a parent group' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: parent_group) }
      let_it_be(:project) { create(:project, :repository, group: child_group) }

      let(:hook) { create(:group_hook, group: parent_group) }
      let(:trigger) { 'not_implemented_events' }
      let(:service) { described_class.new(hook, current_user, trigger) }

      context 'for project_hooks' do
        let(:trigger) { 'project_events' }
        let(:trigger_key) { :project_hooks }

        it 'executes hook' do
          allow_next(Gitlab::HookData::ProjectBuilder).to receive(:build).and_return(sample_data)

          expect(hook).to receive(:execute).with(sample_data, trigger_key, force: true).and_return(success_result)
          expect(service.execute).to include(success_result)
        end
      end
    end
  end
end
