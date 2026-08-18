# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::Variables, feature_category: :pipeline_composition do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before do
    project.add_maintainer(user)

    stub_licensed_features(audit_events: true)
  end

  describe 'GET /projects/:id/variables/:key' do
    include_examples 'audit event for variable access', :ci_variable do
      let(:make_request) { get api("/projects/#{project.id}/variables/#{audited_variable.key}", user) }
      let(:expected_entity) { project }
      let(:variable_attributes) { { project: project, hidden: is_hidden_variable, masked: is_masked_variable } }
    end
  end

  describe 'POST /projects/:id/variables' do
    subject(:post_create) do
      post api("/projects/#{project.id}/variables", user), params: { key: 'new_variable', value: 'secret_value', protected: true }
    end

    it 'audits variable creation' do
      expected_audit_context = {
        name: 'ci_variable_created',
        author: user,
        scope: project,
        target: an_instance_of(::Ci::Variable),
        message: 'Added ci variable'
      }

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

      post_create
    end
  end

  describe 'PUT /projects/:id/variables/:key' do
    let(:variable) { create(:ci_variable, project: project, protected: false) }

    subject(:put_update) do
      put api("/projects/#{project.id}/variables/#{variable.key}", user), params: { protected: true }
    end

    it 'audits variable protection update' do
      expected_audit_context = {
        name: 'ci_variable_updated',
        author: user,
        scope: project,
        target: variable,
        message: 'Changed variable protection from false to true'
      }

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

      put_update
    end
  end

  describe 'DELETE /projects/:id/variables/:key' do
    let(:variable) { create(:ci_variable, project: project, protected: false) }

    subject(:delete_destroy) do
      delete api("/projects/#{project.id}/variables/#{variable.key}", user)
    end

    it 'audits variable destruction' do
      expected_audit_context = {
        name: 'ci_variable_deleted',
        author: user,
        scope: project,
        target: variable,
        message: 'Removed ci variable',
        additional_details: {
          event_name: 'ci_variable_deleted',
          remove: 'ci_variable'
        }
      }

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

      delete_destroy
    end
  end
end
