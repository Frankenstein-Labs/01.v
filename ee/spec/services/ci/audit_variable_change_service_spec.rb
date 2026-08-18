# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::AuditVariableChangeService, feature_category: :pipeline_composition do
  subject(:execute) { service.execute }

  let_it_be(:user) { create(:user) }

  let(:group) { create(:group) }
  let(:container) { group }
  let(:instance_variable) { create(:ci_instance_variable, key: 'CI_DEBUG_TRACE', value: true) }
  let(:group_variable) { create(:ci_group_variable, group: group) }
  let(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }
  let(:project) { create(:project, group: group) }
  let(:project_variable) { create(:ci_variable, project: project) }

  let(:service) do
    described_class.new(
      container: container, current_user: user,
      params: { action: action, variable: variable }
    )
  end

  shared_examples 'audit creation' do
    let(:action) { :create }

    it 'logs audit event' do
      expect { execute }.to change { AuditEventReader.count }.from(0).to(1)
    end

    it 'logs (project/group/instance) variable creation' do
      execute

      audit_event = AuditEventReader.last.presence

      expect(audit_event.details[:custom_message]).to eq(message)
      expect(audit_event.details[:target_details]).to eq(variable.key)
    end

    it_behaves_like 'sends correct event type in audit event stream' do
      let_it_be(:event_type) { event_type }
    end
  end

  shared_examples 'audit when updating variable protection' do
    let(:action) { :update }

    before do
      variable.update!(protected: true)
    end

    it 'logs audit event' do
      expect { execute }.to change { AuditEventReader.count }.from(0).to(1)
    end

    it 'logs variable protection update' do
      execute

      audit_event = AuditEventReader.last.presence

      expect(audit_event.details[:custom_message]).to eq('Changed variable protection from false to true')
      expect(audit_event.details[:target_details]).to eq(variable.key)
    end

    it_behaves_like 'sends correct event type in audit event stream' do
      let_it_be(:event_type) { event_type }
    end
  end

  shared_examples 'audit_when_updating_variable_environment_scope' do
    let(:action) { :update }

    before do
      variable.update!(environment_scope: 'gprd')
    end

    it 'logs audit event' do
      expect { execute }.to change { AuditEventReader.count }.from(0).to(1)
    end

    it 'logs variable environment_scope update' do
      execute

      audit_event = AuditEventReader.last.presence

      expect(audit_event.details[:custom_message]).to eq('Changed environment scope from * to gprd')
      expect(audit_event.details[:target_details]).to eq(variable.key)
    end

    it_behaves_like 'sends correct event type in audit event stream' do
      let_it_be(:event_type) { event_type }
    end
  end

  shared_examples 'audit value change' do
    let(:action) { :update }

    it 'does not log CI variable value' do
      variable.value = 'Super Secret'
      variable.save!

      execute

      audit_event = AuditEventReader.last.presence

      expect(audit_event.details[:custom_message]).to eq('Changed value(hidden)')
      expect(audit_event.details[:custom_message]).not_to include('Super Secret')
      expect(audit_event.details[:custom_message]).not_to include('VARIABLE_VALUE')
      expect(audit_event.details[:target_details]).to eq(variable.key)
    end

    context 'when updated masked' do
      before do
        variable.masked = true
        variable.save!
      end

      it 'logs audit event' do
        expect { execute }.to change { AuditEventReader.count }.from(0).to(1)
      end

      it 'logs variable masked update' do
        execute

        audit_event = AuditEventReader.last.presence

        expect(audit_event.details[:custom_message]).to eq('Changed variable masking from false to true')
        expect(audit_event.details[:target_details]).to eq(variable.key)
      end

      it_behaves_like 'sends correct event type in audit event stream' do
        let_it_be(:event_type) { event_type }
      end
    end

    context 'when masked is and was false' do
      it 'audit with from and to of the value' do
        variable.masked = false
        variable.value = 'A'
        variable.save!
        variable.reload

        variable.value = 'B'

        expect { execute }.not_to change { AuditEventReader.count }
      end
    end
  end

  shared_examples 'no audit events are created' do
    context 'when creating variable' do
      let(:action) { :create }

      it 'does not log an audit event' do
        expect { execute }.not_to change { AuditEventReader.count }.from(0)
      end
    end

    context 'when updating variable protection' do
      let(:action) { :update }

      before do
        variable.update!(protected: true)
      end

      it 'does not log an audit event' do
        expect { execute }.not_to change { AuditEventReader.count }.from(0)
      end
    end

    context 'when destroying variable' do
      let(:action) { :destroy }

      it 'does not log an audit event' do
        expect { execute }.not_to change { AuditEventReader.count }.from(0)
      end
    end
  end

  shared_examples 'when destroying variable' do
    let(:action) { :destroy }

    it 'logs audit event' do
      expect { execute }.to change { AuditEventReader.count }.from(0).to(1)
    end

    it 'logs variable destruction' do
      execute

      audit_event = AuditEventReader.last.presence

      expect(audit_event.action).to eq(message)
      expect(audit_event.target).to eq(variable.key)
    end

    it_behaves_like 'sends correct event type in audit event stream' do
      let_it_be(:event_type) { "ci_group_variable_deleted" }
    end
  end

  context 'when audits are available' do
    let_it_be(:instance_destination) { create(:audit_events_instance_external_streaming_destination) }

    before do
      stub_licensed_features(audit_events: true)
      stub_licensed_features(external_audit_events: true)
    end

    context 'with instance variables' do
      let(:variable) { instance_variable }
      let(:container) { ::Gitlab::Audit::InstanceScope.new }

      context 'when creating instance variable' do
        it_behaves_like 'audit creation' do
          let_it_be(:message) { 'Added ci instance variable' }
          let_it_be(:event_type) { "ci_instance_variable_created" }
        end
      end

      context 'when updating instance variable protection' do
        it_behaves_like 'audit when updating variable protection' do
          let_it_be(:event_type) { "ci_instance_variable_updated" }
        end
      end

      # instance variables do not have an environment_scope so we don't test that here
    end

    context 'with group variables' do
      let(:variable) { group_variable }

      it_behaves_like 'audit value change' do
        let_it_be(:event_type) { "ci_group_variable_updated" }
      end

      context 'when creating group variable' do
        it_behaves_like 'audit creation' do
          let_it_be(:message) { 'Added ci group variable' }
          let_it_be(:event_type) { "ci_group_variable_created" }
        end
      end

      context 'when updating group variable protection' do
        it_behaves_like 'audit when updating variable protection' do
          let_it_be(:event_type) { "ci_group_variable_updated" }
        end
      end

      context 'when updating group variable environment_scope' do
        it_behaves_like 'audit_when_updating_variable_environment_scope' do
          let_it_be(:event_type) { "ci_group_variable_updated" }
        end
      end

      context 'when deleting group variable' do
        it_behaves_like 'audit when updating variable protection' do
          let_it_be(:message) { 'Removed ci group variable' }
          let_it_be(:event_type) { "ci_group_variable_updated" }
        end
      end
    end

    context 'with project variables' do
      let(:variable) { project_variable }

      context 'when creating project variable' do
        it_behaves_like 'audit creation' do
          let_it_be(:message) { 'Added ci variable' }
          let_it_be(:event_type) { "ci_variable_created" }
        end
      end

      context 'when updating project variable protection' do
        it_behaves_like 'audit when updating variable protection' do
          let_it_be(:event_type) { "ci_variable_updated" }
        end
      end

      context 'when updating project variable environment_scope' do
        it_behaves_like 'audit_when_updating_variable_environment_scope' do
          let_it_be(:event_type) { "ci_variable_updated" }
        end
      end

      context 'when deleting project variable' do
        it_behaves_like 'audit when updating variable protection' do
          let_it_be(:message) { 'Removed ci variable' }
          let_it_be(:event_type) { "ci_variable_updated" }
        end
      end
    end
  end

  context 'when audits are not available' do
    before do
      stub_licensed_features(audit_events: false)
    end

    context 'for group variable' do
      it_behaves_like 'no audit events are created' do
        let(:variable) { group_variable }
      end
    end

    context 'for project variable' do
      it_behaves_like 'no audit events are created' do
        let(:variable) { project_variable }
      end
    end
  end
end
