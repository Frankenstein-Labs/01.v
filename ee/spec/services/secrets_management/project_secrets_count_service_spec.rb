# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsCountService,
  :gitlab_secrets_manager,
  feature_category: :secrets_management do
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:service) { described_class.new(project, user) }

  before_all do
    project.add_owner(user)
  end

  before do
    provision_project_secrets_manager(secrets_manager, user)
  end

  describe '#execute' do
    subject(:count) { service.execute }

    context 'when there are no secrets' do
      it 'returns 0' do
        expect(count).to eq(0)
      end
    end

    context 'when there are secrets' do
      before do
        create_project_secret(
          user: user,
          project: project,
          name: 'secret1',
          value: 'value1',
          environment: '*',
          branch: '*'
        )

        create_project_secret(
          user: user,
          project: project,
          name: 'secret2',
          value: 'value2',
          environment: 'production',
          branch: 'main'
        )

        create_project_secret(
          user: user,
          project: project,
          name: 'secret3',
          value: 'value3',
          environment: 'staging',
          branch: 'develop'
        )
      end

      it 'returns the correct count' do
        expect(count).to eq(3)
      end

      it 'uses the correct data path when counting secrets' do
        client = service.send(:project_secrets_manager_client)
        mount_path = secrets_manager.ci_secrets_mount_path
        data_path = secrets_manager.ci_data_path

        expect(client).to receive(:count_secrets)
          .with(mount_path, data_path, limit: nil)
          .and_call_original

        count
      end

      it 'matches the count from ListService' do
        list_service = SecretsManagement::ProjectSecrets::ListService.new(project, user)
        list_result = list_service.execute
        list_count = list_result.payload[:secrets]&.count || 0

        expect(count).to eq(list_count),
          "ProjectSecretsCountService count (#{count}) should match ListService count (#{list_count})"
      end
    end

    context 'when count_secrets is called with wrong path' do
      before do
        create_project_secret(
          user: user,
          project: project,
          name: 'secret1',
          value: 'value1',
          environment: '*',
          branch: '*'
        )
      end

      it 'uses the correct path to count secrets' do
        client = service.send(:project_secrets_manager_client)
        mount_path = secrets_manager.ci_secrets_mount_path

        expect(client).to receive(:count_secrets)
          .with(mount_path, secrets_manager.ci_data_path, limit: nil)
          .and_call_original

        expect(count).to eq(1)
      end
    end

    context 'when OpenBao returns an error' do
      before do
        client = service.send(:project_secrets_manager_client)
        allow(client).to receive(:count_secrets).and_raise(StandardError, 'OpenBao connection failed')
      end

      it 'raises the error' do
        expect { count }.to raise_error(StandardError, 'OpenBao connection failed')
      end
    end
  end

  describe '#secrets_limit_exceeded?' do
    subject(:limit_exceeded) { service.secrets_limit_exceeded? }

    let(:mount_path) { secrets_manager.ci_secrets_mount_path }
    let(:data_path) { secrets_manager.ci_data_path }

    context 'when secrets_limit is 0 (unlimited)' do
      before do
        allow(project.secrets_manager).to receive(:secrets_limit).and_return(0)
      end

      it 'returns false' do
        expect(limit_exceeded).to be(false)
      end

      it 'does not call count_secrets' do
        client = service.send(:project_secrets_manager_client)

        expect(client).not_to receive(:count_secrets)

        limit_exceeded
      end
    end

    context 'when there are secrets below the limit' do
      let(:limit) { 2 }

      before do
        allow(project.secrets_manager).to receive(:secrets_limit).and_return(limit)
        create_project_secret(
          user: user,
          project: project,
          name: 'secret1',
          value: 'value1',
          environment: '*',
          branch: '*'
        )
      end

      it 'returns false and counts with limit + 1' do
        client = service.send(:project_secrets_manager_client)

        expect(client).to receive(:count_secrets)
          .with(mount_path, data_path, limit: limit + 1)
          .and_call_original

        expect(limit_exceeded).to be(false)
      end
    end

    context 'when there are secrets at the limit' do
      let(:limit) { 1 }

      before do
        allow(project.secrets_manager).to receive(:secrets_limit).and_return(limit)
        create_project_secret(
          user: user,
          project: project,
          name: 'secret1',
          value: 'value1',
          environment: '*',
          branch: '*'
        )
      end

      it 'returns true and counts with limit + 1' do
        client = service.send(:project_secrets_manager_client)

        expect(client).to receive(:count_secrets)
          .with(mount_path, data_path, limit: limit + 1)
          .and_call_original

        expect(limit_exceeded).to be(true)
      end
    end
  end
end
