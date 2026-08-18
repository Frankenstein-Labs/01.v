# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyDismissalEntity, feature_category: :security_policy_management do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:merge_request) { build_stubbed(:merge_request, source_project: project) }
  let_it_be(:security_orchestration_policy_configuration) do
    build_stubbed(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:security_policy) do
    build_stubbed(
      :security_policy,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration
    )
  end

  let_it_be(:policy_dismissal) do
    build_stubbed(:policy_dismissal,
      project: project,
      merge_request: merge_request,
      security_policy: security_policy,
      user: user,
      dismissal_types: [0, 1],
      comment: 'Test dismissal comment',
      security_findings_uuids: %w[uuid1 uuid2])
  end

  let(:entity) { described_class.new(policy_dismissal, request: EntityRequest.new(current_user: user)) }

  subject(:entity_json) { entity.as_json }

  it 'exposes the correct attributes' do
    expect(entity_json).to include(
      id: policy_dismissal.id,
      created_at: policy_dismissal.created_at,
      updated_at: policy_dismissal.updated_at,
      project_id: project.id,
      project_name: project.name,
      project_path: project.full_path,
      merge_request_id: merge_request.id,
      security_policy_id: security_policy.id,
      user_id: user.id,
      security_findings_uuids: %w[uuid1 uuid2],
      dismissal_types: ['Policy false positive', 'Scanner false positive'],
      comment: 'Test dismissal comment',
      user_name: user.name,
      user_path: "/#{user.username}"
    )
  end

  context 'when user can read merge request' do
    before do
      stub_member_access_level(project, developer: user)
    end

    it 'exposes merge request information' do
      expect(entity_json).to include(
        merge_request_path: "/#{project.full_path}/-/merge_requests/#{merge_request.iid}",
        merge_request_reference: merge_request.to_reference
      )
    end
  end

  context 'when policy dismissal project is nil' do
    let_it_be(:policy_dismissal_without_project) do
      build_stubbed(:policy_dismissal,
        project: nil,
        merge_request: merge_request,
        security_policy: security_policy,
        user: user,
        dismissal_types: [0],
        security_findings_uuids: [])
    end

    let(:entity) do
      described_class.new(policy_dismissal_without_project, request: EntityRequest.new(current_user: user))
    end

    it 'returns nil for project_name and project_path' do
      expect(entity_json).to include(
        project_name: nil,
        project_path: nil
      )
    end
  end

  context 'when policy dismissal user is nil' do
    let_it_be(:policy_dismissal_without_user) do
      build_stubbed(:policy_dismissal,
        project: project,
        merge_request: merge_request,
        security_policy: security_policy,
        user: nil,
        dismissal_types: [0, 1],
        comment: 'Test dismissal comment',
        security_findings_uuids: %w[uuid1 uuid2])
    end

    let(:entity) { described_class.new(policy_dismissal_without_user, request: EntityRequest.new(current_user: user)) }

    it 'handles nil user gracefully' do
      expect(entity_json).to include(
        id: policy_dismissal_without_user.id,
        created_at: policy_dismissal_without_user.created_at,
        updated_at: policy_dismissal_without_user.updated_at,
        project_id: project.id,
        project_name: project.name,
        project_path: project.full_path,
        merge_request_id: merge_request.id,
        security_policy_id: security_policy.id,
        user_id: nil,
        security_findings_uuids: %w[uuid1 uuid2],
        dismissal_types: ['Policy false positive', 'Scanner false positive'],
        comment: 'Test dismissal comment',
        user_name: nil,
        user_path: nil
      )
    end
  end
end
