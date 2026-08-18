# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::EnforcesWriteEntitlement, feature_category: :secrets_management do
  let_it_be(:current_user) { build_stubbed(:user) }

  let(:namespace) { nil }

  # Stands in for `Mutations::BaseMutation`: defines the `field` DSL method
  # the concern's `included do` block calls, and the `ready?` the concern's
  # `ready?` calls `super` into (mirroring `BaseMutation#ready?` returning
  # `true` when not read-only).
  let(:base_mutation_class) do
    Class.new do
      def self.field(*); end

      def ready?(**)
        true
      end
    end
  end

  let(:host_class) do
    Class.new(base_mutation_class) do
      include SecretsManagement::EnforcesWriteEntitlement

      enforces_write_entitlement_for :project_secret, find_by: :project_path

      attr_reader :current_user, :namespace

      def initialize(current_user, namespace:)
        @current_user = current_user
        @namespace = namespace
      end

      def find_object(project_path:)
        project_path && namespace
      end
    end
  end

  let(:instance) { host_class.new(current_user, namespace: namespace) }

  describe '.enforces_write_entitlement_for' do
    it 'sets entitlement_payload_key and entitlement_find_by_key on the including class' do
      expect(host_class.entitlement_payload_key).to eq(:project_secret)
      expect(host_class.entitlement_find_by_key).to eq(:project_path)
    end

    it 'is independent per including class' do
      other_class = Class.new(base_mutation_class) do
        include SecretsManagement::EnforcesWriteEntitlement
        enforces_write_entitlement_for :group_secret, find_by: :group_path
      end

      expect(other_class.entitlement_payload_key).to eq(:group_secret)
      expect(other_class.entitlement_find_by_key).to eq(:group_path)
      expect(host_class.entitlement_payload_key).to eq(:project_secret)
      expect(host_class.entitlement_find_by_key).to eq(:project_path)
    end
  end

  describe '#ready?' do
    subject(:result) { instance.ready?(project_path: 'group/project', name: 'SOME_SECRET') }

    context 'when namespace is nil' do
      let(:namespace) { nil }

      it 'does not consume Entitlement.for and falls through to the base ready?' do
        expect(SecretsManagement::Entitlement).not_to receive(:for)

        expect(result).to be(true)
      end
    end

    context 'when the feature flag is disabled' do
      let(:namespace) { create(:group) }

      before do
        stub_feature_flags(secrets_manager_paid_experience: false)
      end

      it 'does not consume Entitlement.for and falls through to the base ready?' do
        expect(SecretsManagement::Entitlement).not_to receive(:for)

        expect(result).to be(true)
      end
    end

    context 'when the feature flag is enabled' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: true)
      end

      context 'with a top-level group namespace, and the write is permitted' do
        let(:namespace) { create(:group) }

        it "consumes Entitlement.for the group and falls through to the base ready?" do
          entitlement = instance_double(SecretsManagement::Entitlement, write_action_denial_reason: nil)
          expect(SecretsManagement::Entitlement).to receive(:for)
            .with(namespace, user: current_user).and_return(entitlement)

          expect(result).to be(true)
        end
      end

      context 'with a top-level group namespace, and the write is denied' do
        let(:namespace) { create(:group) }

        before do
          entitlement = instance_double(
            SecretsManagement::Entitlement,
            write_action_denial_reason: :trial_required,
            state: :trial_eligible
          )
          allow(SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
        end

        context 'and the current user can read the group entitlement' do
          before do
            allow(Ability).to receive(:allowed?)
              .with(current_user, :read_secrets_manager, namespace).and_return(true)
          end

          it 'short-circuits with [false, structured payload] instead of calling the base ready?' do
            expect(result).to eq([
              false,
              {
                project_secret: nil,
                errors: [described_class::WRITE_DENIAL_MESSAGE],
                reason: :trial_required
              }
            ])
          end

          it 'emits denial telemetry for the graphql_mutation surface' do
            expect { result }.to trigger_internal_events('secrets_manager_access_denied').with(
              namespace: namespace,
              user: current_user,
              category: 'SecretsManagement::Entitlement::DenialTelemetry',
              additional_properties: {
                label: 'trial_required',
                property: 'graphql_mutation',
                state: 'trial_eligible',
                mode: 'enforce'
              }
            )
          end
        end

        context 'and the current user cannot read the group entitlement' do
          before do
            allow(Ability).to receive(:allowed?)
              .with(current_user, :read_secrets_manager, namespace).and_return(false)
          end

          it 'does not disclose the reason and falls through to the base ready?' do
            expect(result).to be(true)
          end

          it 'does not emit denial telemetry' do
            expect { result }.not_to trigger_internal_events('secrets_manager_access_denied')
          end
        end
      end

      context 'with a project namespace under a top-level group' do
        let(:root_group) { create(:group) }
        let(:namespace) { create(:project, group: root_group) }

        it "resolves entitlement against the project's root_ancestor group" do
          entitlement = instance_double(SecretsManagement::Entitlement, write_action_denial_reason: nil)
          expect(SecretsManagement::Entitlement).to receive(:for)
            .with(root_group, user: current_user).and_return(entitlement)

          expect(result).to be(true)
        end

        context 'and the write is denied' do
          it 'checks the read_project_secrets_manager_status ability against the project itself, ' \
            'not the root group' do
            entitlement = instance_double(
              SecretsManagement::Entitlement, write_action_denial_reason: :ineligible, state: :ineligible
            )
            allow(SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
            expect(Ability).to receive(:allowed?)
              .with(current_user, :read_project_secrets_manager_status, namespace).and_return(true)

            expect(result).to eq([
              false,
              {
                project_secret: nil,
                errors: [described_class::WRITE_DENIAL_MESSAGE],
                reason: :ineligible
              }
            ])
          end
        end
      end

      context 'with a project in a personal namespace (root_ancestor is not a Group)' do
        let_it_be(:namespace) { create(:project, :in_user_namespace) }

        it 'passes nil as the entitlement namespace (instance-level entitlement)' do
          entitlement = instance_double(
            SecretsManagement::Entitlement, write_action_denial_reason: :ineligible, state: :ineligible
          )
          expect(SecretsManagement::Entitlement).to receive(:for)
            .with(nil, user: current_user).and_return(entitlement)
          allow(Ability).to receive(:allowed?)
            .with(current_user, :read_project_secrets_manager_status, namespace).and_return(true)

          expect(result).to eq([
            false,
            {
              project_secret: nil,
              errors: [described_class::WRITE_DENIAL_MESSAGE],
              reason: :ineligible
            }
          ])
        end
      end
    end
  end
end
