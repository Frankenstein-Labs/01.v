# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::KnowledgeGraph::ToggleNamespaceService, feature_category: :knowledge_graph do
  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }

  describe '#execute' do
    subject(:result) { described_class.new(group: group, current_user: owner, enabled: enabled).execute }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_licensed_features(orbit: true)
    end

    context 'when user is not authorized' do
      let_it_be(:developer) { create(:user, developer_of: group) }
      let(:enabled) { true }

      subject(:result) { described_class.new(group: group, current_user: developer, enabled: enabled).execute }

      it 'returns a forbidden error' do
        expect(result).to be_error
        expect(result.reason).to eq(:forbidden)
      end
    end

    context 'when enabling' do
      let(:enabled) { true }

      it 'creates an enabled namespace record' do
        expect { result }.to change { Analytics::KnowledgeGraph::EnabledNamespace.count }.by(1)
        expect(result).to be_success
        expect(result[:group]).to eq(group)
      end

      context 'when already enabled' do
        before do
          create(:knowledge_graph_enabled_namespace, namespace: group)
        end

        it 'is idempotent' do
          expect { result }.not_to change { Analytics::KnowledgeGraph::EnabledNamespace.count }
          expect(result).to be_success
        end
      end

      context 'when a concurrent request creates the record first' do
        it 'handles the race condition gracefully' do
          allow_next_instance_of(Analytics::KnowledgeGraph::EnabledNamespace) do |record|
            allow(record).to receive(:save).and_wrap_original do |_method, *_args|
              raise ActiveRecord::RecordNotUnique
            end
          end

          expect(result).to be_success
        end
      end

      context 'when orbit_enroll_namespace feature flag is disabled' do
        before do
          stub_feature_flags(orbit_enroll_namespace: false)
        end

        it 'is denied by the namespace eligibility policy' do
          expect { result }.not_to change { Analytics::KnowledgeGraph::EnabledNamespace.count }
          expect(result).to be_error
          expect(result.reason).to eq(:forbidden)
        end
      end

      context 'when orbit_enroll_namespace feature flag is enabled for a different group only' do
        let_it_be(:other_group) { create(:group) }

        before do
          stub_feature_flags(orbit_enroll_namespace: other_group)
        end

        it 'is denied for the group not in the flag scope' do
          expect(result).to be_error
          expect(result.reason).to eq(:forbidden)
        end
      end

      context 'when the policy is bypassed but the enrollment flag is off' do
        before do
          allow(Ability).to receive(:allowed?)
            .with(owner, :update_knowledge_graph_setting, group).and_return(true)
          stub_feature_flags(orbit_enroll_namespace: false)
        end

        it 'returns the namespace-not-available error as defense in depth' do
          expect { result }.not_to change { Analytics::KnowledgeGraph::EnabledNamespace.count }
          expect(result).to be_error
          expect(result.message)
            .to eq('GitLab Orbit is not yet available for this namespace. Please try again later.')
        end
      end
    end

    context 'when disabling' do
      let(:enabled) { false }

      context 'when currently enabled' do
        before do
          create(:knowledge_graph_enabled_namespace, namespace: group)
        end

        it 'removes the enabled namespace record' do
          expect { result }.to change { Analytics::KnowledgeGraph::EnabledNamespace.count }.by(-1)
          expect(result).to be_success
        end

        context 'when orbit_enroll_namespace feature flag is disabled' do
          before do
            stub_feature_flags(orbit_enroll_namespace: false)
          end

          it 'still removes the enabled namespace record' do
            expect { result }.to change { Analytics::KnowledgeGraph::EnabledNamespace.count }.by(-1)
            expect(result).to be_success
          end
        end
      end

      context 'when already disabled' do
        it 'is idempotent' do
          expect { result }.not_to change { Analytics::KnowledgeGraph::EnabledNamespace.count }
          expect(result).to be_success
        end
      end

      context 'when destroy fails' do
        before do
          record = create(:knowledge_graph_enabled_namespace, namespace: group)
          allow(record).to receive(:destroy).and_return(false)
          record.errors.add(:base, 'could not be removed')
          allow(group).to receive(:knowledge_graph_enabled_namespace).and_return(record)
        end

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('could not be removed')
        end
      end
    end

    context 'when group is not a root namespace' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let(:enabled) { true }

      subject(:result) do
        described_class.new(group: subgroup, current_user: owner, enabled: enabled).execute
      end

      it 'returns an authorization error' do
        expect(result).to be_error
        expect(result.reason).to eq(:forbidden)
      end
    end
  end
end
