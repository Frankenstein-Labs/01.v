# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::CreateAuditEventService, feature_category: :package_registry do
  # Use `let` with `build_stubbed` - non-persisted objects don't benefit from `let_it_be`.
  let(:project) { build_stubbed(:project, group: build_stubbed(:group)) }
  let(:user) { build_stubbed(:user) }
  let(:package) { build_stubbed(:generic_package, project: project, creator: user) }
  let(:deploy_token) { build_stubbed(:deploy_token) }

  let(:current_user) { nil }
  let(:event_name) { 'package_registry_package_published' }
  let(:service) { described_class.new(package, current_user:, event_name:) }

  describe '#execute' do
    subject(:execute) { service.execute }

    let(:operation) { execute }
    let(:event_type) { event_name }
    let(:fail_condition!) { allow(service).to receive(:audit_events_enabled?).and_return(false) }
    let(:attributes) do
      {
        author_id: user.id,
        entity_id: project.group.id,
        entity_type: 'Group',
        details: {
          author_name: user.name,
          event_name: event_name,
          target_id: package.id,
          target_type: package.class.name,
          target_details: "#{project.full_path}/#{package.name}-#{package.version}",
          author_class: user.class.name,
          custom_message: audit_message,
          auth_token_type: auth_token_type
        }
      }
    end

    before do
      allow(service).to receive(:audit_events_enabled?).and_return(true)
    end

    context 'for package_registry_package_published event' do
      let(:audit_message) { "#{package.package_type.humanize} package published" }
      let(:auth_token_type) { 'PersonalAccessToken or CiJobToken' }

      include_examples 'audit event logging'
    end

    context 'for package_registry_package_deleted event' do
      let(:current_user) { user }
      let(:event_name) { 'package_registry_package_deleted' }
      let(:audit_message) { "#{package.package_type.humanize} package deleted" }
      let(:auth_token_type) { 'PersonalAccessToken' }

      include_examples 'audit event logging'
    end

    context 'when project does not belong to a group' do
      before do
        project.group = nil
      end

      it 'uses project as scope' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(scope: project)
        )

        execute
      end
    end

    context 'for auth token type detection' do
      context 'when Current.token_info is present' do
        before do
          allow(::Current).to receive(:token_info).and_return({ token_type: 'SomeToken' })
        end

        it 'uses token type from Current' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(additional_details: { auth_token_type: 'SomeToken' })
          )

          execute
        end
      end

      context 'with current_user' do
        let(:current_user) { user }

        it 'sets auth_token_type as PersonalAccessToken' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(additional_details: { auth_token_type: 'PersonalAccessToken' })
          )

          execute
        end

        context 'when current user is a deploy token' do
          let(:current_user) { deploy_token }

          it 'sets auth_token_type as DeployToken' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
              hash_including(additional_details: { auth_token_type: 'DeployToken' })
            )

            execute
          end
        end

        context 'when current user is a CiJobToken' do
          before do
            allow(current_user).to receive(:from_ci_job_token?).and_return(true)
          end

          it 'sets auth_token_type as CiJobToken' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
              hash_including(additional_details: { auth_token_type: 'CiJobToken' })
            )

            execute
          end
        end
      end

      context 'when package has no creator' do
        before do
          allow(package).to receive(:creator).and_return(nil)
        end

        it 'uses DeployTokenAuthor as author' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              author: kind_of(::Gitlab::Audit::DeployTokenAuthor),
              additional_details: { auth_token_type: 'DeployToken' }
            )
          )

          execute
        end
      end

      context 'when package has a creator' do
        it 'sets auth_token_type as PersonalAccessToken or CiJobToken' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(additional_details: { auth_token_type: 'PersonalAccessToken or CiJobToken' })
          )

          execute
        end

        context 'when user is from ci job token' do
          before do
            allow(user).to receive(:from_ci_job_token?).and_return(true)
          end

          it 'sets auth_token_type as CiJobToken' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
              hash_including(additional_details: { auth_token_type: 'CiJobToken' })
            )

            execute
          end
        end
      end
    end
  end
end
