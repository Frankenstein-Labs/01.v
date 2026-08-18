# frozen_string_literal: true

require "spec_helper"

RSpec.describe Projects::RepositoriesController, feature_category: :source_code_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :small_repo, namespace: group, developers: user) }

  describe "GET archive" do
    subject(:get_archive) do
      get :archive, params: { namespace_id: project.namespace, project_id: project, id: "master" }, format: "zip"
    end

    def set_group_destination
      create(:audit_events_group_external_streaming_destination, group: group)
      stub_licensed_features(external_audit_events: true)
    end

    shared_examples 'sends the streaming audit event' do
      it 'sends the streaming event with audit event type' do
        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
          event_type,
          nil,
          a_string_including("author_name\":\"#{user_name}", "custom_message\":\"Repository Download Started")
        )

        get_archive
      end
    end

    context 'when unauthenticated', 'for a public project' do
      let_it_be_with_reload(:project) { create(:project, :small_repo, :public) }

      it 'does not log audit event' do
        expect { get_archive }.not_to change { AuditEventReader.count }
      end

      context 'when group sets event destination' do
        before do
          set_group_destination
        end

        it_behaves_like 'sends the streaming audit event' do
          let_it_be_with_reload(:project) { create(:project, :small_repo, :public, namespace: group) }
          let_it_be(:event_type) { "public_repository_download_operation" }
          let_it_be(:user_name) { "An unauthenticated user" }
        end
      end
    end

    context 'when authenticated', 'as a developer' do
      let_it_be(:user_name) { user.name }

      before do
        sign_in(user)
      end

      it 'logs the audit event' do
        expect { get_archive }.to change { AuditEventReader.count }.by(1)

        unless AuditEventReader.last.details.empty?
          expect(AuditEventReader.last.details).to include({
            author_name: user_name,
            custom_message: "Repository Download Started",
            target_id: project.id,
            target_type: "Project"
          })
        end
      end

      context 'when group sets event destination' do
        before do
          set_group_destination
        end

        context 'when project is public' do
          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
          end

          it_behaves_like 'sends the streaming audit event' do
            let(:event_type) { "public_repository_download_operation" }
            let_it_be(:user_name) { user.name }
          end
        end

        context 'when project is not public' do
          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
          end

          it_behaves_like 'sends the streaming audit event' do
            let(:event_type) { "repository_download_operation" }
            let_it_be(:user_name) { user.name }
          end
        end
      end
    end
  end
end
