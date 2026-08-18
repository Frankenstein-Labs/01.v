# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runners::CreateGkeProvisioningStepsService, feature_category: :fleet_visibility do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:runner) { create(:ci_runner, :project, projects: [project], token: 'v__x-zPvFbogsYEgaCq-') }
  let_it_be(:group_maintainer) { create(:user, maintainer_of: group) }
  let_it_be(:project_maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:group_owner) { create(:user, owner_of: group) }
  let_it_be(:project_owner) { project.owner }

  where(:type, :container, :current_user, :container_owner) do
    'group'   | ref(:group)   | ref(:group_maintainer)   | ref(:group_owner)
    'project' | ref(:project) | ref(:project_maintainer) | ref(:project_owner)
  end

  with_them do
    let(:google_cloud_project_id) { 'google_project_id' }
    let(:region) { 'us-central1' }
    let(:zone) { 'us-central1-a' }
    let(:runner_token) { runner.token }
    let(:node_pools) { nil }
    let(:params) do
      {
        google_cloud_project_id: google_cloud_project_id,
        region: region,
        zone: zone,
        runner_token: runner_token,
        node_pools: node_pools
      }
    end

    subject(:execute) do
      described_class.new(container: container, current_user: current_user, params: params).execute
    end

    it 'returns an error' do
      expect(execute.status).to eq :error
      expect(execute.reason).to eq :insufficient_permissions
      expect(execute.message).to eq s_('Runners|The user is not allowed to provision a GKE runner')
    end

    context 'with saas-only feature enabled' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      it 'returns provisioning steps' do
        expect(execute.status).to eq :success

        steps = execute.payload[:provisioning_steps]
        expect(steps).to match([
          {
            instructions: a_string_including("google_region"),
            language_identifier: 'terraform',
            title: s_('Runners|Save the Terraform script to a file')
          },
          {
            instructions: a_string_including("runner_token"),
            language_identifier: 'shell',
            title: s_('Runners|Apply the Terraform script')
          }
        ])
      end

      context 'with nil runner token' do
        let(:current_user) { container_owner }
        let(:runner_token) { nil }

        it 'is successful and generates a unique deployment id' do
          # NOTE: use a known tricky token value instead of generating random ones
          expect(Devise).to receive(:friendly_token).with(Ci::Runner::RUNNER_SHORT_SHA_LENGTH).and_return('v__x-zP-')

          expect(execute).to be_success

          steps = execute.payload[:provisioning_steps]
          expect(steps).to match([
            a_hash_including(instructions: /name = "grit-v--x-zp"/),
            an_instance_of(Hash)
          ])
        end

        context 'when new deployment name is invalid' do
          it 'returns internal error' do
            expect(Devise).to receive(:friendly_token).with(Ci::Runner::RUNNER_SHORT_SHA_LENGTH).and_return('1234567/')

            expect(execute).to be_error
            expect(execute.reason).to eq :internal_error
            expect(execute.message).to eq s_('Runners|The deployment name is invalid')
          end
        end

        context 'when new deployment name ends with dashes' do
          it 'removes the trailing dashes' do
            expect(Devise).to receive(:friendly_token).with(Ci::Runner::RUNNER_SHORT_SHA_LENGTH).and_return('1234----')

            expect(execute).to be_success

            steps = execute.payload[:provisioning_steps]
            expect(steps).to match([
              a_hash_including(instructions: /name = "grit-1234"/),
              an_instance_of(Hash)
            ])
          end
        end

        context 'when user does not have permissions to create runner' do
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(current_user, :create_runners, anything).and_return(false)
          end

          it 'returns an error' do
            expect(execute).to be_error
            expect(execute.reason).to eq :insufficient_permissions
            expect(execute.message).to eq s_('Runners|The user is not allowed to create a runner')
          end
        end
      end

      context 'with invalid runner token' do
        let(:runner_token) { 'invalid-token' }

        it 'returns an error' do
          expect(execute).to be_error
          expect(execute.reason).to eq :invalid_argument
          expect(execute.message).to eq s_('Runners|The runner authentication token is invalid')
        end
      end

      context 'with invalid region name' do
        let(:region) { '" invalid-region "' }

        it 'uses a sanitized value' do
          expect(execute).to be_success

          steps = execute.payload[:provisioning_steps]
          expect(steps).to match([
            a_hash_including(instructions: a_string_including("google_region  = \"\" invalid-region _\"")),
            an_instance_of(Hash)
          ])
        end
      end

      context 'with invalid zone name' do
        let(:zone) { '" invalid-zone "' }

        it 'uses a sanitized value' do
          expect(execute).to be_success

          steps = execute.payload[:provisioning_steps]
          expect(steps).to match([
            a_hash_including(instructions: a_string_including("google_zone    = \"\" invalid-zone _\"")),
            an_instance_of(Hash)
          ])
        end
      end

      context 'with node_pools provided' do
        let(:node_pools) do
          [{ node_count: 10, machine_type: 'n2d-standard-2', image_type: 'ubuntu', name: 'node_pool_1' }]
        end

        it 'returns steps with node_pools set up' do
          expect(execute).to be_success

          steps = execute.payload[:provisioning_steps]
          expect(steps).to match([
            a_hash_including(instructions: /node_count = 10/),
            an_instance_of(Hash)
          ])
        end
      end

      context 'when user is not authorized' do
        let(:current_user) { create(:user, developer_of: container) }

        it 'returns an error' do
          allow(Ability).to receive(:allowed?).and_call_original
          expect(Ability).to receive(:allowed?).with(current_user, :provision_gke_runner, container).and_call_original

          expect(execute).to be_error
          expect(execute.reason).to eq :insufficient_permissions
          expect(execute.message).to eq s_('Runners|The user is not allowed to provision a GKE runner')
        end
      end
    end

    context 'with saas-only feature disabled' do
      before do
        stub_saas_features(google_cloud_support: false)
      end

      it 'return an error' do
        expect(execute).to be_error
        expect(execute.reason).to eq :insufficient_permissions
        expect(execute.message).to eq s_('Runners|The user is not allowed to provision a GKE runner')
      end
    end
  end
end
