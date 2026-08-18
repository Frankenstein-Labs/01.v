# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Autocomplete::UsersFinder, feature_category: :code_review_workflow do
  include Ai::Catalog::FlowFactoryHelpers

  describe '#execute' do
    let(:current_user) { create(:user) }
    let(:params) { {} }

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject(:users) do
      described_class.new(params: params, current_user: current_user, project: project, group: nil).execute.to_a
    end

    describe '#project_users' do
      let_it_be(:duo_code_review_bot) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }

      context 'when project does not have access to Duo Code review' do
        before do
          allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(false)
        end

        it { is_expected.not_to include(duo_code_review_bot) }
      end

      context 'when project has access Duo Code review' do
        before do
          allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(true)
        end

        it { is_expected.to include(duo_code_review_bot) }
      end
    end

    describe '#associations_to_preload' do
      subject(:associations) do
        users.flat_map do |user|
          [user.association(:ai_flow_triggers), user.association(:child_item_consumers_flow_triggers)]
        end
      end

      before do
        create(:user, developer_of: project)
      end

      context 'when preload_flow_triggers is true' do
        let(:params) do
          {
            preload_flow_triggers: true
          }
        end

        it 'preloads ai_flow_triggers' do
          expect(associations).to all(be_loaded)
        end
      end

      context 'when preload_flow_triggers is false' do
        let(:params) do
          {
            preload_flow_triggers: false
          }
        end

        it 'does not preload ai_flow_triggers' do
          expect(associations).to all(satisfy { |association| !association.loaded? })
        end
      end
    end
  end
end
