# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ToolRules::UpsertService, feature_category: :ai_agents do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }

  let(:rule) do
    Ai::ToolRule.find_or_initialize_for_namespace(
      namespace_id: namespace.id,
      tool_name: 'create_issue'
    )
  end

  subject(:service) { described_class.new(rule, current_user, params) }

  describe '#execute' do
    before do
      allow(Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when the rule is new' do
      let(:params) { { web_access: :allow } }

      it 'returns a success response' do
        expect(service.execute).to be_success
      end

      it 'persists the rule' do
        expect { service.execute }.to change { Ai::ToolRule.count }.by(1)
      end

      it 'returns the rule as payload' do
        response = service.execute
        expect(response.payload).to eq(rule)
        expect(response.payload.web_access).to eq('allow')
      end

      it 'emits a created audit event' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'ai_tool_rule_created',
            author: current_user,
            scope: namespace,
            target: rule,
            message: "Created tool rule for create_issue: web_access=allow, local_access=, background_access="
          )
        )

        service.execute
      end
    end

    context 'when background_access is set' do
      let(:params) { { background_access: :deny } }

      it 'persists background_access and records it in the created audit message', :aggregate_failures do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(message: a_string_including('background_access=deny'))
        )

        expect(service.execute).to be_success
        expect(rule.reload.background_access).to eq('deny')
      end
    end

    context 'when the rule already exists' do
      let(:existing_rule) do
        create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :allow)
      end

      let(:rule) { existing_rule }
      let(:params) { { web_access: :deny } }

      it 'updates the existing rule without creating a new one' do
        existing_rule

        expect { service.execute }.not_to change { Ai::ToolRule.count }
      end

      it 'returns the updated rule' do
        response = service.execute

        expect(response.payload.web_access).to eq('deny')
      end

      it 'emits an updated audit event with correct additional_details' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'ai_tool_rule_updated',
            author: current_user,
            scope: namespace,
            target: existing_rule,
            message: "Updated tool rule for create_issue: web_access allow->deny",
            additional_details: hash_including(
              tool_name: 'create_issue',
              web_access_from: 'allow',
              web_access_to: 'deny'
            )
          )
        )

        service.execute
      end

      it 'does not include unchanged fields in additional_details' do
        service.execute

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            additional_details: satisfy { |d|
              !d.key?(:local_access_from) && !d.key?(:local_access_to)
            }
          )
        )
      end
    end

    context 'when an existing rule changes background_access' do
      let(:existing_rule) do
        create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', background_access: :allow)
      end

      let(:rule) { existing_rule }
      let(:params) { { background_access: :deny } }

      it 'persists the change' do
        expect { service.execute }.to change { existing_rule.reload.background_access }.from('allow').to('deny')
      end

      it 'records background_access in the updated audit message and details', :aggregate_failures do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'ai_tool_rule_updated',
            message: 'Updated tool rule for create_issue: background_access allow->deny',
            additional_details: hash_including(
              background_access_from: 'allow',
              background_access_to: 'deny'
            )
          )
        )

        service.execute
      end
    end

    context 'when both web_access and local_access change' do
      let(:existing_rule) do
        create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :allow, local_access: :allow)
      end

      let(:rule) { existing_rule }
      let(:params) { { web_access: :deny, local_access: :ask } }

      it 'includes both fields in the audit message' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'ai_tool_rule_updated',
            message: "Updated tool rule for create_issue: web_access allow->deny, local_access allow->ask"
          )
        )

        service.execute
      end
    end

    context 'when no fields change' do
      let(:existing_rule) do
        create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :allow)
      end

      let(:rule) { existing_rule }
      let(:params) { { web_access: :allow } }

      it 'does not emit an updated audit event' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit)

        service.execute
      end
    end

    context 'when only web_access is provided' do
      let(:params) { { web_access: :ask, local_access: nil } }

      it 'only updates web_access' do
        service.execute
        expect(rule.web_access).to eq('ask')
        expect(rule.local_access).to be_nil
      end
    end

    context 'when only local_access is provided' do
      let(:params) { { web_access: nil, local_access: :deny } }

      it 'only updates local_access' do
        service.execute
        expect(rule.local_access).to eq('deny')
        expect(rule.web_access).to be_nil
      end
    end

    context 'when the rule fails to save' do
      let(:params) { { web_access: :allow } }

      before do
        allow(rule).to receive(:save).and_return(false)
        allow(rule.errors).to receive(:full_messages).and_return(['web_access is invalid'])
      end

      it 'returns an error response' do
        expect(service.execute).to be_error
      end

      it 'includes the validation errors' do
        expect(service.execute.message).to include('web_access is invalid')
      end

      it 'does not emit an audit event' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit)

        service.execute
      end
    end

    context 'when user is not authorized' do
      let(:params) { { web_access: :allow } }
      let(:current_user) { create(:user) }

      it 'returns an error response' do
        expect(service.execute).to be_error
      end

      it 'does not persist the rule' do
        expect { service.execute }.not_to change { Ai::ToolRule.count }
      end

      it 'does not emit a tool rule audit event' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(
          hash_including(name: a_string_starting_with('ai_tool_rule'))
        )

        service.execute
      end
    end

    context 'when updating a project-scoped rule' do
      let_it_be(:project) { create(:project, namespace: namespace) }

      let(:rule) do
        Ai::ToolRule.find_or_initialize_for_namespace(
          namespace_id: namespace.id,
          tool_name: 'create_issue',
          project_id: project.id
        )
      end

      let(:params) { { web_access: :deny } }

      before do
        stub_feature_flags(gitlab_duo_governance_settings: true)
        allow(project).to receive(:duo_features_enabled).and_return(true)
      end

      context 'when user is a maintainer' do
        let_it_be(:maintainer) { create(:user, maintainer_of: project) }
        let(:current_user) { maintainer }

        it 'is authorized and saves the rule', :aggregate_failures do
          expect(service.execute).to be_success
          expect(Ai::ToolRule.find_by(namespace_id: namespace.id, project_id: project.id,
            tool_name: 'create_issue')).to be_present
        end
      end

      context 'when user is a developer' do
        let_it_be(:developer) { create(:user, developer_of: project) }
        let(:current_user) { developer }

        it 'returns an error response' do
          expect(service.execute).to be_error
        end
      end
    end
  end
end
