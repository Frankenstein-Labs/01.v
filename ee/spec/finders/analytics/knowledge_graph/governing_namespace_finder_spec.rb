# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::KnowledgeGraph::GoverningNamespaceFinder, feature_category: :knowledge_graph do
  let_it_be(:user) { create(:user, :with_namespace) }

  subject(:finder) { described_class.new(user) }

  describe '#candidates' do
    context 'when SaaS', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when user belongs to namespaces with various plan and Orbit configurations' do
        # Eligible: paid plan + Orbit enabled
        let_it_be(:premium_namespace) { create(:group, name: 'premium_namespace') }
        let_it_be(:ultimate_namespace) { create(:group, name: 'ultimate_namespace') }

        # Excluded: paid plan but Orbit NOT enabled
        let_it_be(:premium_without_orbit_namespace) do
          create(:group, name: 'premium_without_orbit_namespace')
        end

        # Excluded: Orbit enabled but no paid plan
        let_it_be(:orbit_only_namespace) { create(:group, name: 'orbit_only_namespace') }

        # Excluded: trial plan
        let_it_be(:premium_trial_namespace) { create(:group, name: 'premium_trial_namespace') }
        let_it_be(:ultimate_trial_namespace) { create(:group, name: 'ultimate_trial_namespace') }

        # Excluded: free plan
        let_it_be(:free_namespace) { create(:group, name: 'free_namespace') }

        let_it_be(:premium_subscription) do
          create(:gitlab_subscription, :premium, namespace: premium_namespace)
        end

        let_it_be(:ultimate_subscription) do
          create(:gitlab_subscription, :ultimate, namespace: ultimate_namespace)
        end

        let_it_be(:premium_without_orbit_subscription) do
          create(:gitlab_subscription, :premium, namespace: premium_without_orbit_namespace)
        end

        let_it_be(:premium_trial_subscription) do
          create(:gitlab_subscription, :premium, :active_trial, namespace: premium_trial_namespace)
        end

        let_it_be(:ultimate_trial_subscription) do
          create(:gitlab_subscription, :ultimate, :active_trial, namespace: ultimate_trial_namespace)
        end

        before_all do
          [premium_namespace, ultimate_namespace, orbit_only_namespace].each do |namespace|
            create(:knowledge_graph_enabled_namespace, namespace: namespace)
          end

          [premium_namespace, ultimate_namespace, premium_without_orbit_namespace, orbit_only_namespace,
            premium_trial_namespace, ultimate_trial_namespace, free_namespace].each do |namespace|
            namespace.add_developer(user)
          end
        end

        it 'returns only paid premium/ultimate namespaces with Orbit enabled' do
          expect(finder.candidates).to match_array([premium_namespace, ultimate_namespace])
        end

        it 'excludes paid namespaces without Orbit enabled' do
          expect(finder.candidates).not_to include(premium_without_orbit_namespace)
        end

        it 'excludes Orbit-enabled namespaces without a paid plan' do
          expect(finder.candidates).not_to include(orbit_only_namespace)
        end

        it 'excludes trial plan namespaces' do
          expect(finder.candidates).not_to include(premium_trial_namespace, ultimate_trial_namespace)
        end
      end

      it 'is empty when user has no paid plans' do
        expect(finder.candidates).to be_empty
      end
    end

    context 'when Self-Managed' do
      let_it_be(:top_level_group) { create(:group) }

      before_all do
        top_level_group.add_maintainer(user)
        create(:knowledge_graph_enabled_namespace, namespace: top_level_group)
      end

      it 'returns no namespaces' do
        expect(finder.candidates).to be_empty
      end
    end
  end

  describe '#eligible?' do
    let_it_be(:namespace) { create(:group, :private) }

    it 'returns false when namespace_id is nil' do
      expect(finder.eligible?(nil)).to be false
    end

    it 'returns true when the namespace is in candidates' do
      allow(finder).to receive(:candidates).and_return(Namespace.where(id: namespace.id))

      expect(finder.eligible?(namespace.id)).to be true
    end

    it 'returns false when the namespace is not in candidates' do
      allow(finder).to receive(:candidates).and_return(Namespace.none)

      expect(finder.eligible?(namespace.id)).to be false
    end
  end

  describe '#single_candidate_fallback' do
    let_it_be(:namespace) { create(:group, :private) }
    let_it_be(:other_namespace) { create(:group, :private) }

    it 'returns the namespace when exactly one candidate exists' do
      allow(finder).to receive(:candidates).and_return(Namespace.where(id: namespace.id))

      expect(finder.single_candidate_fallback).to eq(namespace)
    end

    it 'returns nil when multiple candidates exist' do
      allow(finder).to receive(:candidates)
        .and_return(Namespace.where(id: [namespace.id, other_namespace.id]))

      expect(finder.single_candidate_fallback).to be_nil
    end

    it 'returns nil when no candidates exist' do
      allow(finder).to receive(:candidates).and_return(Namespace.none)

      expect(finder.single_candidate_fallback).to be_nil
    end
  end
end
