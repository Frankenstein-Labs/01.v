# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
# noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
RSpec.describe RemoteDevelopment::Workspace, :freeze_time, feature_category: :workspaces do
  include_context "with constant modules"

  let(:workspaces_agent_config_enabled) { true }
  let(:workspaces_per_user_quota) { 10 }
  let(:workspaces_quota) { 10 }
  let(:dns_zone) { "workspace.me" }
  let(:desired_state) { states_module::RUNNING }
  let(:actual_state) { states_module::STOPPED }

  let_it_be(:common_organization) { create(:common_organization) }
  let_it_be(:group) { create(:group, organization: common_organization) }

  let_it_be_with_reload(:agent) { create(:ee_cluster_agent, project: create(:project, namespace: group)) }
  let_it_be_with_reload(:agent_config) { create(:workspaces_agent_config, agent: agent) }
  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:project) { create(:project, namespace: group) }

  subject(:workspace) do
    build(
      :workspace, user: user, agent: agent, project: project,
      personal_access_token: personal_access_token, desired_state: desired_state,
      actual_state: actual_state
    )
  end

  before do
    # Assign let variables to let_it_be fixtures, this must be done here in a before(:each), not in a
    # before(:context). let_it_be is implemented as a before(:context), so you can't use the let
    # declarations directly from within them.
    agent_config.update!(
      workspaces_per_user_quota: workspaces_per_user_quota,
      workspaces_quota: workspaces_quota,
      dns_zone: dns_zone,
      enabled: workspaces_agent_config_enabled
    )
    # Some tests would trigger method trigger_update_workspace_to_active_event with HTTPS call
    stub_request(:post, "https://events-stg.gitlab.net/com.snowplowanalytics.snowplow/tp2").to_return(status: 200,
      body: "", headers: {})
  end

  describe "associations" do
    context "for has_many" do
      it { is_expected.to have_many(:workspace_variables) }
    end

    context "for has_one" do
      it { is_expected.to have_one(:workspace_agentk_state) }
      it { is_expected.to have_one(:workspace_token) }
    end

    context "for belongs_to" do
      it { is_expected.to belong_to(:user) }
      it { is_expected.to belong_to(:personal_access_token) }

      it "has correct relation setup" do
        is_expected
          .to belong_to(:agent)
            .class_name("Clusters::Agent")
            .with_foreign_key(:cluster_agent_id)
            .inverse_of(:workspaces)
      end
    end

    context "when from factory" do
      let_it_be_with_reload(:created_workspace) { create(:workspace) }

      it "has correct associations from factory" do
        expect(created_workspace.user).to be_valid
        expect(created_workspace.project).to be_valid
        expect(created_workspace.agent).to be_valid
        expect(created_workspace.personal_access_token).to be_valid
        expect(created_workspace.agent.unversioned_latest_workspaces_agent_config.workspaces.first)
          .to eq(created_workspace)
        expect(created_workspace.url_prefix)
          .to eq("#{create_constants_module::WORKSPACE_EDITOR_PORT}-#{created_workspace.name}")
        expect(created_workspace.url_query_string).to eq("folder=dir%2Ffile")
        expect(created_workspace.workspace_agentk_state).not_to be_nil
        expect(created_workspace.workspace_agentk_state).to be_valid
        expect(created_workspace.workspace_agentk_state.desired_config).not_to be_nil
        expect(
          RemoteDevelopment::WorkspaceOperations::DesiredConfig.new(
            desired_config_array: created_workspace.workspace_agentk_state.desired_config
          )
        ).to be_valid
      end
    end
  end

  describe "callbacks" do
    describe "before_save" do
      describe "when creating new record" do
        it "sets desired_state_updated_at" do
          workspace.save!
          expect(workspace.desired_state_updated_at).to eq(Time.current)
        end

        it "sets actual_state_updated_at" do
          workspace.save!
          expect(workspace.actual_state_updated_at).to eq(Time.current)
        end
      end

      describe "when updating desired_state" do
        it "sets desired_state_updated_at" do
          expect { workspace.update!(desired_state: states_module::RUNNING) }.to change {
            workspace.desired_state_updated_at
          }
        end
      end

      describe "when updating actual_state" do
        it "sets desired_state_updated_at" do
          expect { workspace.update!(actual_state: states_module::RUNNING) }.to change {
            workspace.actual_state_updated_at
          }
        end
      end

      describe "when updating a field other than desired_state" do
        it "does not set desired_state_updated_at" do
          workspace.save!
          expect { workspace.update!(actual_state: states_module::RUNNING) }.not_to change {
            workspace.desired_state_updated_at
          }
        end

        it "does not set actual_state_updated_at" do
          workspace.save!
          expect { workspace.update!(actual_state: states_module::RUNNING) }.not_to change {
            workspace.actual_state_updated_at
          }
        end
      end
    end

    describe "before_validation" do
      context "on create" do
        context "when agent_config has more than 1 version" do
          before do
            agent_config.touch
          end

          it "sets workspaces_agent_config_version to number of versions" do
            # We are calling #valid? to exercise the `before_validation` callback.
            # This value is 3 because that's the number of versions that exist at this point based on previous updates
            # to the fixtures. See
            # https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/remote_development/README.md#workspaces_agent_configs-versioning
            # for more details on how versioning works and why this value is 3.
            workspace.valid?
            expect(workspace.workspaces_agent_config_version).to eq(3)
          end
        end
      end
    end

    describe "after_save" do
      describe "track_started_workspace callback" do
        context "when desired_state changes to Running" do
          let(:desired_state) { states_module::STOPPED }

          it "triggers the event" do
            expect(workspace).to receive(:track_started_workspace)
            workspace.update!(desired_state: states_module::RUNNING)
          end

          it "triggers internal event with new label on new record" do
            expect { workspace.update!(desired_state: states_module::RUNNING) }
              .to trigger_internal_events("track_started_workspaces")
                .with(user: user, project: project, namespace: project.namespace, additional_properties: {
                  label: "new"
                })
                .and increment_usage_metrics("counts.count_total_workspaces_started")
          end

          it "triggers internal event with existing label on existing record" do
            workspace.save!(desired_state: "Stopped")
            expect { workspace.update!(desired_state: states_module::RUNNING) }
              .to trigger_internal_events("track_started_workspaces")
                .with(user: user, project: project, namespace: project.namespace, additional_properties: {
                  label: "existing"
                })
                .and increment_usage_metrics("counts.count_total_workspaces_started")
          end
        end

        context "when desired_state changes to a value other than Running" do
          let(:desired_state) { states_module::RUNNING }

          it "does not trigger the event and metric" do
            expect { workspace.update!(desired_state: states_module::STOPPED) }
              .to not_trigger_internal_events("track_started_workspaces")
                .and not_increment_usage_metrics('counts.count_total_workspaces_started')
          end
        end

        context "when desired_state doesn't change" do
          before do
            workspace.save!
          end

          it "does not trigger the event" do
            expect { workspace.update!(name: "workspace_new_name") }
              .to not_trigger_internal_events("track_started_workspaces")
                .and not_increment_usage_metrics('counts.count_total_workspaces_started')
          end
        end
      end

      describe "WorkspaceToken creation" do
        context "for a new record" do
          it "creates an associated WorkspaceToken record" do
            expect(workspace).to be_new_record # fixture sanity check

            expect { workspace.save! }.to change {
              RemoteDevelopment::WorkspaceToken.count
            }.by(1)

            expect(workspace.workspace_token).not_to be_nil
          end
        end

        context "for an existing record" do
          context "when changing to Running" do
            using RSpec::Parameterized::TableSyntax

            let(:desired_state) { states_module::STOPPED }

            before do
              workspace.save!
            end

            it "creates an associated WorkspaceToken record" do
              expect(workspace.workspace_token).to be_nil # fixture sanity check

              expect { workspace.update!(desired_state: states_module::RUNNING) }.to change {
                RemoteDevelopment::WorkspaceToken.count
              }.by(1)

              expect(workspace.workspace_token).not_to be_nil
            end

            context "when WorkspaceToken record already exists" do
              before do
                workspace.create_workspace_token!
              end

              it "does not raise an error" do
                expect { workspace.update!(desired_state: states_module::RUNNING) }.not_to raise_error

                expect(workspace.workspace_token).not_to be_nil
              end

              it "rotates (recreates) the existing token" do
                previous_token_id = workspace.workspace_token.id

                expect { workspace.update!(desired_state: states_module::RUNNING) }.not_to change {
                  RemoteDevelopment::WorkspaceToken.count
                }

                expect(workspace.workspace_token.id).not_to eq(previous_token_id)
              end
            end
          end
        end
      end

      describe "WorkspaceToken deletion" do
        before do
          workspace.save!
        end

        context "when changing from Running" do
          using RSpec::Parameterized::TableSyntax

          let(:desired_state) { states_module::RUNNING }

          shared_examples "deletes the associated WorkspaceToken record if it exists" do
            it "deletes the associated WorkspaceToken record if it exists when Stopped" do
              expect { workspace.update!(desired_state: new_desired_state) }.to change {
                RemoteDevelopment::WorkspaceToken.count
              }.by(-1)

              expect(workspace.workspace_token).to be_nil
            end

            it "does not raise an error when WorkspaceToken record does not exist" do
              workspace.workspace_token.destroy!
              workspace.reload

              expect { workspace.update!(desired_state: new_desired_state) }.not_to raise_error
            end
          end

          where(:new_desired_state) do
            [
              states_module::RESTART_REQUESTED,
              states_module::STOPPED,
              states_module::TERMINATED
            ]
          end

          with_them do
            it_behaves_like "deletes the associated WorkspaceToken record if it exists"
          end
        end
      end
    end
  end

  describe "validations" do
    context "on agent.unversioned_latest_workspaces_agent_config" do
      context "when no config is present" do
        before do
          agent.unversioned_latest_workspaces_agent_config.destroy!
          agent.reload
        end

        it "validates presence of agent.unversioned_latest_workspaces_agent_config" do
          # sanity check of fixture
          expect(workspace.agent.unversioned_latest_workspaces_agent_config).not_to be_present

          expect(workspace).not_to be_valid
          expect(workspace.errors.full_messages).to include("Agent must have an associated workspaces agent config")
        end
      end

      context "on agent_config enabled" do
        context "when agent is enabled" do
          it "validates presence of agent.workspaces_agent_config" do
            expect(workspace).to be_valid
          end
        end

        context "when agent is disabled" do
          let(:workspaces_agent_config_enabled) { false }

          it "validates agent.unversioned_latest_workspaces_agent_config is enabled" do
            expect(workspace).not_to be_valid
            expect(workspace.errors[:agent])
              .to include("must have the 'enabled' flag set to true")
          end

          it "is only validated on create" do
            workspace.workspaces_agent_config_version = 1
            workspace.save(validate: false) # rubocop:disable Rails/SaveBang -- intentional to test validation
            workspace.valid?
            expect(workspace.errors[:agent]).to be_blank
          end
        end
      end
    end

    context "on workspaces_agent_config_version" do
      context "when version is greater than version range" do
        before do
          workspace.save!
          workspace.workspaces_agent_config_version = agent_config.versions.size + 1
        end

        it "raises error message as expected" do
          expect(workspace).not_to be_valid
          expect(workspace.errors.full_messages).to include(
            "Workspaces agent config version must be no greater than the number of agent config versions"
          )
        end
      end

      context "when version is less than 0" do
        before do
          workspace.save!
          workspace.workspaces_agent_config_version = -1
        end

        it "raises error message as expected" do
          expect(workspace).not_to be_valid
          expect(workspace.errors.full_messages).to include(
            "Workspaces agent config version must be greater than or equal to 0"
          )
        end
      end
    end

    context "on desired_state" do
      context "when desired_state is Terminated" do
        let(:desired_state) { states_module::TERMINATED }

        it "prevents changes to desired_state" do
          workspace.save!
          updated = workspace.update(desired_state: states_module::STOPPED)
          expect(updated).to be(false)
          expect(workspace).not_to be_valid
          expect(workspace.errors[:desired_state])
            .to include("is 'Terminated', and cannot be updated. Create a new workspace instead.")
        end
      end
    end

    describe "on workspaces_per_user_quota" do
      before do
        allow(workspace)
          .to receive(:workspaces_count_for_current_user_and_agent)
            .and_return(workspaces_count_for_current_user_and_agent)
      end

      describe "when quotas are not exceeded" do
        shared_context "and not exceeding per user quota" do
          let(:workspaces_per_user_quota) { 2 }
          let(:workspaces_count_for_current_user_and_agent) { 1 }

          it "does not add base errors when quotas are not exceeded" do
            workspace.validate
            expect(workspace.errors[:base]).to be_empty
          end
        end

        context "when workspaces_per_user_quota is -1" do
          let(:workspaces_per_user_quota) { -1 }
          let(:workspaces_count_for_current_user_and_agent) { 99 }

          it_behaves_like "and not exceeding per user quota"
        end
      end

      context "when quotas are exceeded" do
        shared_examples "exceeds per user quota" do
          it "adds per user quota exceeded error to base error" do
            workspace.validate

            message = "You cannot create a workspace because you already have " \
              "'#{workspaces_count_for_current_user_and_agent}' existing workspaces for the given agent " \
              "which has a per user quota of '#{workspaces_per_user_quota}' workspaces"
            expect(workspace.errors[:base]).to include(message)
          end
        end

        context "when workspaces_per_user_quota is 0" do
          let(:workspaces_per_user_quota) { 0 }
          let(:workspaces_count_for_current_user_and_agent) { 0 }

          it_behaves_like "exceeds per user quota"
        end

        context "when workspaces count for current user and agent is equal to the quota" do
          let(:workspaces_per_user_quota) { 1 }
          let(:workspaces_count_for_current_user_and_agent) { 1 }

          it_behaves_like "exceeds per user quota"
        end

        context "when workspaces count for current user and agent is greater than the quota" do
          let(:workspaces_per_user_quota) { 1 }
          let(:workspaces_count_for_current_user_and_agent) { 2 }

          it_behaves_like "exceeds per user quota"
        end
      end
    end

    describe "on enforce_workspaces_quota" do
      before do
        allow(workspace).to receive(:workspaces_count_for_current_agent).and_return(workspaces_count_for_current_agent)
      end

      describe "when quotas are not exceeded" do
        shared_examples "does not exceed quota" do
          let(:workspaces_quota) { 2 }
          let(:workspaces_count_for_current_agent) { 1 }

          it "does not add base errors when quotas are not exceeded" do
            workspace.validate
            expect(workspace.errors[:base]).to be_empty
          end
        end

        context "when workspaces_quota is -1" do
          let(:workspaces_quota) { -1 }
          let(:workspaces_count_for_current_agent) { 99 }

          it_behaves_like "does not exceed quota"
        end
      end

      context "when quotas are exceeded" do
        shared_examples "exceeds quota" do
          before do
            workspace.send(:set_workspaces_agent_config_version)
          end

          it "adds quota exceeded error to base error" do
            workspace.validate

            message = "You cannot create a workspace because there are already " \
              "'#{workspaces_count_for_current_agent}' existing workspaces for the given agent " \
              "which has a quota of '#{workspaces_quota}' workspaces"
            expect(workspace.errors[:base]).to include(message)
          end
        end

        context "when workspaces_quota is 0" do
          let(:workspaces_quota) { 0 }
          let(:workspaces_count_for_current_agent) { 0 }

          it_behaves_like "exceeds quota"
        end

        context "when workspaces count for agent is equal to the quota" do
          let(:workspaces_quota) { 1 }
          let(:workspaces_count_for_current_agent) { 1 }

          it_behaves_like "exceeds quota"
        end

        context "when workspaces count for agent is greater than the quota" do
          let(:workspaces_quota) { 1 }
          let(:workspaces_count_for_current_agent) { 2 }

          it_behaves_like "exceeds quota"
        end
      end
    end
  end

  describe "scopes" do
    describe "with_desired_state_updated_more_recently_than_last_response_to_agent" do
      context "when responded_to_agent_at is nil" do
        before do
          workspace.save!
          workspace.update!(
            desired_state_updated_at: DateTime.now.advance(minutes: 20),
            responded_to_agent_at: nil
          )
        end

        it "includes workspace" do
          # fixture sanity check
          expect(workspace.responded_to_agent_at).to be_nil

          expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
            .to include(workspace)

          # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
          expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to be(true)
        end
      end

      context "when responded_to_agent_at is not nil" do
        context "when desired_state_updated_at is greater than responded_to_agent_at" do
          before do
            workspace.save!
            workspace.update!(
              desired_state_updated_at: DateTime.now.advance(minutes: 20),
              responded_to_agent_at: DateTime.now.advance(minutes: 10)
            )
          end

          it "includes workspace" do
            # fixture sanity check
            expect(workspace.desired_state_updated_at).to be > workspace.responded_to_agent_at

            expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
              .to include(workspace)

            # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
            expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to be(true)
          end
        end

        context "when desired_state_updated_at is equal to responded_to_agent_at" do
          before do
            workspace.save!
            workspace.update!(
              desired_state_updated_at: DateTime.now.advance(minutes: 10),
              responded_to_agent_at: DateTime.now.advance(minutes: 10)
            )
          end

          it "does not include workspace" do
            # fixture sanity check
            expect(workspace.desired_state_updated_at).to eq(workspace.responded_to_agent_at)

            expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
              .not_to include(workspace)

            # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
            expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to be(false)
          end
        end

        context "when desired_state_updated_at is less than responded_to_agent_at" do
          before do
            workspace.save!
            workspace.update!(
              desired_state_updated_at: DateTime.now.advance(minutes: 10),
              responded_to_agent_at: DateTime.now.advance(minutes: 20)
            )
          end

          it "does not include workpace" do
            # fixture sanity check
            expect(workspace.desired_state_updated_at).to be < workspace.responded_to_agent_at

            expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
              .not_to include(workspace)

            # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
            expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to be(false)
          end
        end
      end
    end

    describe "with_actual_state_updated_more_recently_than_last_response_to_agent" do
      context "when workspace responded_to_agent_at is nil" do
        before do
          workspace.save!
          workspace.update!(
            actual_state_updated_at: DateTime.now.advance(minutes: 20),
            responded_to_agent_at: nil
          )
        end

        it "returns workspace" do
          expect(described_class.with_actual_state_updated_more_recently_than_last_response_to_agent)
            .to include(workspace)
        end
      end

      context "when actual_state_updated_at is greater than responded_to_agent_at" do
        context "when responded_to_agent_at is nil" do
          before do
            workspace.save!
            workspace.update!(
              actual_state_updated_at: DateTime.now.advance(minutes: 20),
              responded_to_agent_at: nil
            )
          end

          it "returns true" do
            # fixture sanity check
            expect(workspace.responded_to_agent_at).to be_nil

            expect(workspace.actual_state_updated_more_recently_than_last_response_to_agent?).to be(true)
          end
        end

        context "when responded_to_agent_at is not nil" do
          context "when actual_state_updated_at is greater than responded_to_agent_at" do
            before do
              workspace.save!
              workspace.update!(
                actual_state_updated_at: DateTime.now.advance(minutes: 20),
                responded_to_agent_at: DateTime.now.advance(minutes: 10)
              )
            end

            it "includes workspace" do
              # fixture sanity check
              expect(workspace.actual_state_updated_at).to be > workspace.responded_to_agent_at

              expect(described_class.with_actual_state_updated_more_recently_than_last_response_to_agent)
                .to include(workspace)

              # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
              expect(workspace.actual_state_updated_more_recently_than_last_response_to_agent?).to be(true)
            end
          end

          context "when actual_state_updated_at is equal to responded_to_agent_at" do
            before do
              workspace.save!
              workspace.update!(
                actual_state_updated_at: DateTime.now.advance(minutes: 10),
                responded_to_agent_at: DateTime.now.advance(minutes: 10)
              )
            end

            it "does not include workpace" do
              # fixture sanity check
              expect(workspace.actual_state_updated_at).to eq(workspace.responded_to_agent_at)

              expect(described_class.with_actual_state_updated_more_recently_than_last_response_to_agent)
                .not_to include(workspace)

              # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
              expect(workspace.actual_state_updated_more_recently_than_last_response_to_agent?).to be(false)
            end
          end

          context "when actual_state_updated_at is less than responded_to_agent_at" do
            before do
              workspace.save!
              workspace.update!(
                actual_state_updated_at: DateTime.now.advance(minutes: 10),
                responded_to_agent_at: DateTime.now.advance(minutes: 20)
              )
            end

            it "does not include workpace" do
              # fixture sanity check
              expect(workspace.actual_state_updated_at).to be < workspace.responded_to_agent_at

              expect(described_class.with_actual_state_updated_more_recently_than_last_response_to_agent)
                .not_to include(workspace)

              # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
              expect(workspace.actual_state_updated_more_recently_than_last_response_to_agent?).to be(false)
            end
          end
        end
      end
    end

    describe "with_desired_state_or_actual_state_not_terminated" do
      context "when desired_state is terminated but actual_state is not terminated" do
        let(:desired_state) { states_module::TERMINATED }
        let(:actual_state) { states_module::TERMINATING }

        it "returns workspace" do
          workspace.save!
          expect(described_class.with_desired_state_or_actual_state_not_terminated)
            .to include(workspace)
        end
      end

      context "when both actual_state and desired_state are not terminated" do
        let(:desired_state) { states_module::RUNNING }
        let(:actual_state) { states_module::RUNNING }

        it "returns workspace" do
          workspace.save!
          expect(described_class.with_desired_state_or_actual_state_not_terminated)
            .to include(workspace)
        end
      end

      context "when both actual_state and desired_state are terminated" do
        let(:desired_state) { states_module::TERMINATED }
        let(:actual_state) { states_module::TERMINATED }

        it "does not returns workspace" do
          workspace.save!
          expect(described_class.with_desired_state_or_actual_state_not_terminated)
            .not_to include(workspace)
        end
      end
    end

    describe "with_desired_state_terminated_and_actual_state_not_terminated" do
      context "when workspace desired_state is not terminated" do
        let(:desired_state) { states_module::STOPPED }

        context "when workspace actual_state is not terminated" do
          let(:actual_state) { states_module::STOPPED }

          it "returns workspace" do
            workspace.save!
            expect(described_class.with_desired_state_terminated_and_actual_state_not_terminated)
              .not_to include(workspace)
          end
        end

        context "when workspace actual_state is terminated" do
          let(:actual_state) { states_module::TERMINATED }

          it "returns workspace" do
            workspace.save!
            expect(described_class.with_desired_state_terminated_and_actual_state_not_terminated)
              .not_to include(workspace)
          end
        end
      end

      context "when workspace desired_state is terminated" do
        let(:desired_state) { states_module::TERMINATED }

        context "when workspace actual_state is not terminated" do
          let(:actual_state) { states_module::STOPPED }

          it "returns workspace" do
            workspace.save!
            expect(described_class.with_desired_state_terminated_and_actual_state_not_terminated).to include(workspace)
          end
        end

        context "when workspace actual_state is terminated" do
          let(:actual_state) { states_module::TERMINATED }

          it "returns workspace" do
            workspace.save!
            expect(described_class.with_desired_state_terminated_and_actual_state_not_terminated)
              .not_to include(workspace)
          end
        end
      end
    end

    describe "desired_state_not_terminated" do
      context "when workspace desired_state is not terminated" do
        let(:desired_state) { states_module::STOPPED }

        it "returns workspace" do
          workspace.save!
          expect(described_class.desired_state_not_terminated).to include(workspace)
        end
      end

      context "when workspace desired_state is terminated" do
        let(:desired_state) { states_module::TERMINATED }

        it "returns workspace" do
          workspace.save!
          expect(described_class.desired_state_not_terminated).not_to include(workspace)
        end
      end
    end

    describe "actual_state_not_terminated" do
      context "when workspace actual_state is not terminated" do
        let(:actual_state) { states_module::STOPPED }

        it "returns workspace" do
          workspace.save!
          expect(described_class.actual_state_not_terminated).to include(workspace)
        end
      end

      context "when workspace actual_state is terminated" do
        let(:actual_state) { states_module::TERMINATED }

        it "when workspace actual_state is terminated" do
          workspace.save!
          expect(described_class.actual_state_not_terminated).not_to include(workspace)
        end
      end
    end
  end

  describe "methods" do
    describe "#url" do
      before do
        workspace.send(:set_workspaces_agent_config_version)
      end

      it "returns calculated url" do
        expect(workspace.url).to eq("https://#{create_constants_module::WORKSPACE_EDITOR_PORT}-#{workspace.name}." \
          "#{dns_zone}/?folder=dir%2Ffile")
      end
    end

    describe "#devfile_web_url" do
      it "returns web url to devfile" do
        # noinspection HttpUrlsUsage - suppress RubyMine warning for insecure http link.
        expect(workspace.devfile_web_url)
          .to eq("http://#{Gitlab.config.gitlab.host}/#{workspace.project.path_with_namespace}/-/blob/main/.devfile.yaml")
      end

      context "when devfile_path is nil" do
        before do
          # noinspection RubyMismatchedArgumentType - RubyMine thinks devfile_path can't be nilable, but it can
          workspace.devfile_path = nil
        end

        it "returns nil as devfile_web_url" do
          expect(workspace.devfile_web_url).to be_nil
        end
      end
    end

    describe "#workspaces_count_for_current_user_and_agent" do
      let_it_be(:user1) { create(:user) }
      let_it_be(:user2) { create(:user) }
      let_it_be(:user3) { create(:user) }
      let_it_be_with_reload(:agent1) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be_with_reload(:agent2) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:workspace1) do
        create(
          :workspace, user: user1, agent: agent1,
          desired_state: states_module::RUNNING)
      end

      let_it_be(:workspace2) do
        create(
          :workspace, user: user2, agent: agent1,
          desired_state: states_module::TERMINATED)
      end

      let_it_be(:workspace3) do
        create(
          :workspace, user: user1, agent: agent1,
          desired_state: states_module::STOPPED)
      end

      let_it_be(:workspace4) do
        create(
          :workspace, user: user2, agent: agent2,
          desired_state: states_module::TERMINATED)
      end

      let_it_be(:workspace5) do
        create(
          :workspace, user: user3, agent: agent2,
          desired_state: states_module::RUNNING)
      end

      it "returns the correct count for the current user and agent" do
        expect(workspace1.send(:workspaces_count_for_current_user_and_agent)).to eq(2)
        expect(workspace2.send(:workspaces_count_for_current_user_and_agent)).to eq(0)
        expect(workspace3.send(:workspaces_count_for_current_user_and_agent)).to eq(2)
        expect(workspace4.send(:workspaces_count_for_current_user_and_agent)).to eq(0)
        expect(workspace5.send(:workspaces_count_for_current_user_and_agent)).to eq(1)
      end
    end

    describe "#workspaces_count_for_current_agent" do
      let_it_be_with_reload(:agent1) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be_with_reload(:agent2) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:workspace1) do
        create(:workspace, agent: agent1, desired_state: states_module::RUNNING)
      end

      let_it_be(:workspace2) do
        create(:workspace, agent: agent1, desired_state: states_module::TERMINATED)
      end

      let_it_be(:workspace3) do
        create(:workspace, agent: agent1, desired_state: states_module::STOPPED)
      end

      let_it_be(:workspace4) do
        create(:workspace, agent: agent2, desired_state: states_module::TERMINATED)
      end

      let_it_be(:workspace5) do
        create(:workspace, agent: agent2, desired_state: states_module::RUNNING)
      end

      it "returns the correct count for the current agent" do
        expect(workspace1.send(:workspaces_count_for_current_agent)).to eq(2)
        expect(workspace4.send(:workspaces_count_for_current_agent)).to eq(1)
        expect(workspace5.send(:workspaces_count_for_current_agent)).to eq(1)
      end
    end

    describe "#workspaces_agent_config" do
      context "when agent is nil" do
        before do
          workspace.agent = nil
        end

        it "raises error message as expected" do
          expect do
            workspace.workspaces_agent_config
          end.to raise_error(RuntimeError,
            "#workspaces_agent_config cannot be called until " \
              "#agent and #agent.unversioned_latest_workspaces_agent_config are set.")
        end
      end

      context "when agent.unversioned_latest_workspaces_agent_config is nil" do
        before do
          workspace.save!
          allow(workspace.agent).to receive(:unversioned_latest_workspaces_agent_config).and_return(nil)
        end

        it "raises error message as expected" do
          expect do
            workspace.workspaces_agent_config
          end.to raise_error(RuntimeError,
            "#workspaces_agent_config cannot be called until " \
              "#agent and #agent.unversioned_latest_workspaces_agent_config are set.")
        end
      end

      context "when version is nil" do
        before do
          allow(workspace).to receive(:workspaces_agent_config_version).and_return(nil)
        end

        it "raises error message as expected" do
          expect do
            workspace.workspaces_agent_config
          end.to raise_error(RuntimeError,
            "#workspaces_agent_config cannot be called until #workspaces_agent_config_version is set. " \
              "Call set_workspaces_agent_config_version first to automatically set it.")
        end
      end
    end
  end
end
