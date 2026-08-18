# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::Setup, :gitlab_duo, :silence_stdout, feature_category: :duo_chat do
  include RakeHelpers

  let!(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- development setup seeds records in the default organization
  let!(:group) { create(:group, path: 'gitlab-duo') }
  let!(:project) { create(:project, group: group) }
  let!(:user) { create(:user, :admin, maintainer_of: project, username: 'root') }

  let(:task) { described_class.new(args) }
  let(:namespace) { 'gitlab-duo' }
  let(:custom_namespace) { 'custom-duo-group' }

  let(:feature_flags) do
    [
      :enable_hamilton_in_user_preferences,
      :organization_switching
    ]
  end

  before_all do
    Rake.application.rake_require 'tasks/seed_fu'
    Rake::Task.define_task(:environment)
  end

  subject(:setup) { task.execute }

  before do
    feature_flags.each { |flag| ::Feature.disable(flag) }
    create_current_license_without_expiration(plan: License::ULTIMATE_PLAN)
  end

  shared_examples 'checks for dev or test env' do
    context 'with production environment' do
      before do
        allow(::Gitlab).to receive(:dev_or_test_env?).and_return(false)
      end

      it 'raises an error' do
        expect { setup }.to raise_error(RuntimeError)
      end
    end
  end

  shared_examples 'enables all necessary feature flags' do
    it 'enables all necessary feature flags', :aggregate_failures do
      setup

      feature_flags.each do |flag|
        expect(::Feature.enabled?(flag)).to be_truthy # rubocop:disable Gitlab/FeatureFlagWithoutActor -- For dev
      end
    end
  end

  shared_examples 'errors when there is no license' do
    context 'when there is no license' do
      it 'raises an error' do
        License.delete_all

        expect { setup }.to raise_error(RuntimeError)
      end
    end
  end

  shared_examples 'creates add-on purchases' do
    it 'creates duo core and enterprise add-on purchases by default', :aggregate_failures do
      setup

      expect(::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.count).to eq(0)
      expect(::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.count).to eq(1)
      expect(::GitlabSubscriptions::AddOnPurchase.for_duo_core.count).to eq(1)
    end
  end

  shared_examples 'enables all foundational flows' do
    it 'enables every foundational flow and schedules the consumer sync', :aggregate_failures do
      flow_refs = ::Ai::Catalog::FoundationalFlow.all.map(&:foundational_flow_reference)

      expect(::Ai::Catalog::Flows::CascadeSyncFoundationalFlowsWorker).to receive(:perform_async)
        .with(group.id, User.admins.first.id, match_array(flow_refs))

      setup

      expect(group.reload.namespace_settings.duo_foundational_flows_enabled).to be(true)
      expect(project.reload.project_setting.duo_foundational_flows_enabled).to be(true)
      expect(group.enabled_flow_catalog_item_ids.size).to eq(flow_refs.size)
    end
  end

  context 'when simulating GitLabCom', :saas do
    let(:args) { {} }

    before do
      stub_env('GITLAB_SIMULATE_SAAS', '1')

      original_paths = SeedFu.fixture_paths
      allow(SeedFu).to receive(:fixture_paths).and_return(
        original_paths + ['ee/db/fixtures/development']
      )

      stub_env('SEED_GITLAB_DUO', '1')
      allow(SeedFu).to receive(:seed).and_call_original
    end

    context 'when group does not exist' do
      before do
        group.destroy!
      end

      it 'creates a new group and adds user to group' do
        expect { setup }.to change { ::Group.count }.by(1)
        expect(Group.find_by_path('gitlab-duo').reload.users).to include(user)
      end
    end

    context 'when group already exists' do
      it 'does not create a new group' do
        expect { setup }.not_to change { ::Group.count }
      end
    end

    context 'when creating duo pro add on' do
      let(:args) { { add_on: 'duo_pro' } }

      it 'creates duo core and duo pro add-on' do
        setup

        expect(::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.count).to eq(1)
        expect(::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.count).to eq(0)
        expect(::GitlabSubscriptions::AddOnPurchase.for_duo_core.count).to eq(1)
      end
    end

    context 'when creating duo core add on' do
      let(:args) { { add_on: 'duo_core' } }

      it 'creates duo core add-on only' do
        setup

        expect(::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.count).to eq(0)
        expect(::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.count).to eq(0)
        expect(::GitlabSubscriptions::AddOnPurchase.for_duo_core.count).to eq(1)
      end
    end

    context 'when creating self hosted dap add on' do
      let(:args) { { add_on: 'self_hosted_dap' } }

      it 'creates duo core and self hosted dap add-on' do
        setup

        expect(::GitlabSubscriptions::AddOnPurchase.for_self_hosted_dap.count).to eq(1)
        expect(::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.count).to eq(0)
        expect(::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.count).to eq(0)
        expect(::GitlabSubscriptions::AddOnPurchase.for_duo_core.count).to eq(1)
      end
    end

    it_behaves_like 'checks for dev or test env'
    it_behaves_like 'enables all necessary feature flags'
    it_behaves_like 'errors when there is no license'
    it_behaves_like 'creates add-on purchases'
    it_behaves_like 'enables all foundational flows'

    it 'creates add on purchases for the right group, and not for the entire instance' do
      setup

      expect(::GitlabSubscriptions::AddOnPurchase.by_namespace(group).count).to eq(2)
      expect(::GitlabSubscriptions::AddOnPurchase.by_namespace(nil).count).to eq(0)
    end

    it 'adds an ultimate license with 100 seats' do
      setup

      subscription = ::GitlabSubscription.find_by(namespace: group)

      expect(subscription).to be_present
      expect(subscription.hosted_plan.name).to eq('ultimate')
      expect(subscription.seats).to eq(100)
    end

    context 'when updating application setting' do
      it 'changes application settings' do
        expect { setup }.to change {
                              Gitlab::CurrentSettings.current_application_settings.check_namespace_plan
                            }.to(true)
         .and change {
                Gitlab::CurrentSettings.current_application_settings
                                              .allow_local_requests_from_web_hooks_and_services
              }.to(true)
      end
    end
  end

  context 'when simulating SelfManaged: applying for entire instance' do
    before do
      allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)

      stub_env('GITLAB_SIMULATE_SAAS', '0')
      stub_env('DEVELOPMENT_AI_GATEWAY_URL', 'http://localhost:5052')
    end

    let(:rake_task) { instance_double(Rake::Task, invoke: true) }

    let(:args) { {} }

    context 'when License does not exist' do
      it 'raises an error' do
        License.delete_all

        expect { setup }.to raise_error(RuntimeError)
      end
    end

    it_behaves_like 'checks for dev or test env'
    it_behaves_like 'enables all necessary feature flags'
    it_behaves_like 'errors when there is no license'
    it_behaves_like 'creates add-on purchases'
    it_behaves_like 'enables all foundational flows'

    it 'sets up add on purchases for the entire instance, and not for a specific group' do
      setup

      expect(::GitlabSubscriptions::AddOnPurchase.by_namespace(nil).count).to eq(2)
      expect(::GitlabSubscriptions::AddOnPurchase.by_namespace(group).count).to eq(0)
    end

    context 'when neither DEVELOPMENT_AI_GATEWAY_URL nor AI_GATEWAY_URL is set' do
      before do
        stub_env('DEVELOPMENT_AI_GATEWAY_URL', nil)
        stub_env('AI_GATEWAY_URL', nil)
      end

      it 'raises an error before running the setup' do
        expect { setup }.to raise_error(RuntimeError, /DEVELOPMENT_AI_GATEWAY_URL.*AI_GATEWAY_URL/m)
      end
    end

    context 'when DEVELOPMENT_AI_GATEWAY_URL is set' do
      it 'configures the AI Gateway URL from DEVELOPMENT_AI_GATEWAY_URL' do
        setup

        expect(::Gitlab::CurrentSettings.ai_gateway_url).to eq('http://localhost:5052')
      end
    end

    context 'when only AI_GATEWAY_URL is set' do
      before do
        stub_env('DEVELOPMENT_AI_GATEWAY_URL', nil)
        stub_env('AI_GATEWAY_URL', 'http://localhost:5053')
      end

      it 'falls back to AI_GATEWAY_URL' do
        setup

        expect(::Gitlab::CurrentSettings.ai_gateway_url).to eq('http://localhost:5053')
      end
    end

    context 'when both are set' do
      before do
        stub_env('AI_GATEWAY_URL', 'http://localhost:5053')
      end

      it 'prefers DEVELOPMENT_AI_GATEWAY_URL' do
        setup

        expect(::Gitlab::CurrentSettings.ai_gateway_url).to eq('http://localhost:5052')
      end
    end

    context 'when DEVELOPMENT_AI_GATEWAY_URL has a trailing slash' do
      before do
        stub_env('DEVELOPMENT_AI_GATEWAY_URL', 'http://localhost:5052/')
      end

      it 'strips the trailing slash before configuring the AI Gateway URL' do
        setup

        expect(::Gitlab::CurrentSettings.ai_gateway_url).to eq('http://localhost:5052')
      end
    end
  end

  context 'when seeding GitLab Duo data' do
    let(:strategy) { Gitlab::Duo::Developments::SelfManagedStrategy.new(namespace, {}) }
    let(:rake_task) { instance_double(Rake::Task, :seed_fu) }

    before do
      allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)
      allow(rake_task).to receive(:invoke)
      allow(rake_task).to receive(:reenable)
      allow($stdout).to receive(:puts)
    end

    context 'when GitLab Duo data is not seeded' do
      before do
        allow(Group).to receive(:find_by_full_path).with(namespace).and_return(nil)
      end

      it 'prints a message indicating seeding is happening' do
        expect($stdout).to receive(:puts).with('Seeding GitLab Duo data...')

        strategy.send(:seed_data)
      end

      it 'reenables and invokes the db:seed_fu rake task' do
        strategy.send(:seed_data)

        expect(rake_task).to have_received(:reenable)
        expect(rake_task).to have_received(:invoke)
      end
    end

    context 'when GitLab Duo data is already seeded' do
      before do
        allow(Group).to receive(:find_by_full_path).with(namespace).and_return(group)
      end

      let(:expected_already_seeded_message) do
        <<~TXT.strip
          ================================================================================
          ## GitLab Duo test group and project already seeded
          ## If you want to destroy and re-create them, you can re-run the seed task
          ## SEED_GITLAB_DUO=1 FILTER=gitlab_duo bundle exec rake db:seed_fu
          ## Or set GITLAB_DUO_RESEED=1 to force reseeding via this setup task
          ## See https://docs.gitlab.com/development/development_seed_files/#seed-project-and-group-resources-for-gitlab-duo
          ================================================================================
        TXT
      end

      it 'prints a message indicating data is already seeded and does not run seeds' do
        expect($stdout).to receive(:puts).with(expected_already_seeded_message)

        strategy.send(:seed_data)

        expect(rake_task).not_to have_received(:invoke)
      end

      context 'when GITLAB_DUO_RESEED=1 is set' do
        it 'forces reseeding' do
          stub_env('GITLAB_DUO_RESEED', '1')

          strategy.send(:seed_data)

          expect(rake_task).to have_received(:reenable)
          expect(rake_task).to have_received(:invoke)
        end
      end
    end
  end

  describe 'custom namespace via environment variable' do
    let(:args) { {} }

    context 'when GITLAB_DUO_GROUP_PATH is set' do
      before do
        stub_env('GITLAB_DUO_GROUP_PATH', custom_namespace)
      end

      it 'uses the custom namespace from environment variable' do
        custom_task = described_class.new(args)
        expect(custom_task.instance_variable_get(:@namespace)).to eq(custom_namespace)
      end
    end

    context 'when GITLAB_DUO_GROUP_PATH is not set' do
      it 'uses the default namespace' do
        expect(task.instance_variable_get(:@namespace)).to eq('gitlab-duo')
      end
    end
  end
end
