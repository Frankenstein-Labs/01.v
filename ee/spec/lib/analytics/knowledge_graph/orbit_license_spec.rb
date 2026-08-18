# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::KnowledgeGraph::OrbitLicense, feature_category: :knowledge_graph do
  let_it_be(:user) { create(:user) }

  describe '.available_for?' do
    subject(:available) { described_class.available_for?(user) }

    context 'when user is nil' do
      let(:user) { nil }

      it { is_expected.to be(false) }
    end

    context 'on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when the instance license includes :orbit' do
        before do
          stub_licensed_features(orbit: true)
        end

        it { is_expected.to be(true) }
      end

      context 'when the instance license does not include :orbit' do
        before do
          stub_licensed_features(orbit: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when the user has no authorized groups' do
        it { is_expected.to be(false) }
      end

      context 'when the user belongs to a top-level group with :orbit' do
        let_it_be(:group) { create(:group).tap { |g| g.add_reporter(user) } }

        before do
          stub_licensed_features(orbit: true)
        end

        it { is_expected.to be(true) }

        context 'when :orbit_enroll_namespace is disabled for the group' do
          before do
            stub_feature_flags(orbit_enroll_namespace: false)
          end

          it { is_expected.to be(false) }

          context 'and the group is already enrolled' do
            before do
              create(:knowledge_graph_enabled_namespace, namespace: group)
            end

            it { is_expected.to be(true) }
          end
        end
      end

      context 'when the user belongs to a top-level group without :orbit' do
        let_it_be(:group) { create(:group).tap { |g| g.add_reporter(user) } }

        before do
          stub_licensed_features(orbit: false)
        end

        it { is_expected.to be(false) }
      end

      context 'when the user is a Reporter only on a subgroup' do
        # authorized_groups.top_level is empty for this user (authorized_groups
        # excludes ancestors of direct memberships), so the old predicate
        # denied them. Resolution via traversal_ids.first must now recognize
        # the licensed + enrolled root.
        let_it_be(:root_group) { create(:group) }
        let_it_be(:subgroup) { create(:group, parent: root_group) }

        before_all do
          subgroup.add_reporter(user)
        end

        before do
          stub_licensed_features(orbit: true)
        end

        it 'has an empty authorized_groups.top_level, confirming the old check would deny' do
          expect(user.authorized_groups.top_level).to be_empty
        end

        it { is_expected.to be(true) }

        context 'when the root namespace is enrolled but enrollment flag is disabled' do
          before do
            stub_feature_flags(orbit_enroll_namespace: false)
          end

          it { is_expected.to be(false) }

          context 'and the root namespace is already enrolled' do
            before do
              create(:knowledge_graph_enabled_namespace, namespace: root_group)
            end

            it { is_expected.to be(true) }
          end
        end

        context 'when the root namespace is not :orbit-licensed' do
          before do
            stub_licensed_features(orbit: false)
          end

          it { is_expected.to be(false) }
        end
      end

      context 'with sibling subgroups under one root' do
        # Reporter on subgroup A only; sibling B is untouched. Entitlement is a
        # per-user boolean resolved from the user's own paths, so membership in
        # A grants entitlement through the shared root without depending on B.
        let_it_be(:root_group) { create(:group) }
        let_it_be(:subgroup_a) { create(:group, parent: root_group) }
        let_it_be(:subgroup_b) { create(:group, parent: root_group) }

        before_all do
          subgroup_a.add_reporter(user)
        end

        before do
          stub_licensed_features(orbit: true)
        end

        it { is_expected.to be(true) }
      end

      context 'when the user is a Reporter on a subgroup of an unlicensed root' do
        let_it_be(:root_group) { create(:group) }
        let_it_be(:subgroup) { create(:group, parent: root_group) }

        before_all do
          subgroup.add_reporter(user)
        end

        before do
          stub_licensed_features(orbit: false)
        end

        it { is_expected.to be(false) }
      end

      context 'when the user is a Guest on a subgroup of a licensed root' do
        # Below Reporter, so Search::GroupsFinder(min_access_level: REPORTER)
        # returns no rows and no root is resolved.
        let_it_be(:root_group) { create(:group) }
        let_it_be(:subgroup) { create(:group, parent: root_group) }

        before_all do
          subgroup.add_guest(user)
        end

        before do
          stub_licensed_features(orbit: true)
        end

        it { is_expected.to be(false) }
      end

      context 'when the user has Reporter+ on two roots with mixed licensing' do
        # One root is :orbit-licensed, the other is not. Entitlement resolves
        # per-root and `.any?` short-circuits on the licensed root, so the user
        # is entitled. Licensing is stubbed per-Group (rather than globally) so
        # the assertion proves per-root resolution rather than a global stub.
        let_it_be(:licensed_root) { create(:group) }
        let_it_be(:unlicensed_root) { create(:group) }

        before_all do
          licensed_root.add_reporter(user)
          unlicensed_root.add_reporter(user)
        end

        before do
          roots = [licensed_root, unlicensed_root]
          allow(roots).to receive(:include_gitlab_subscription_with_hosted_plan).and_return(roots)

          allow(Group).to receive(:id_in).and_call_original
          allow(Group).to receive(:id_in)
            .with(contain_exactly(licensed_root.id, unlicensed_root.id))
            .and_return(roots)
          allow(licensed_root).to receive(:licensed_feature_available?).with(:orbit).and_return(true)
          allow(unlicensed_root).to receive(:licensed_feature_available?).with(:orbit).and_return(false)
        end

        it { is_expected.to be(true) }

        context 'when only the unlicensed root would otherwise be enrolled' do
          # Sanity: enrollment on the unlicensed root does not grant access;
          # the licensed root is what carries entitlement.
          before do
            stub_feature_flags(orbit_enroll_namespace: false)
            create(:knowledge_graph_enabled_namespace, namespace: licensed_root)
          end

          it { is_expected.to be(true) }
        end
      end

      context 'when the user is Reporter+ on a group linked into a licensed root' do
        # Arm 3 (GroupGroupLink): the user is a direct member of `sharing_group`,
        # which is shared into `shared_root` at Reporter. Search::GroupsFinder
        # resolves this path to `shared_root`'s traversal, so the user is
        # entitled through a root they have no direct membership in. This is the
        # shared/invited-group behavior called out as a live (admitted) case in
        # open question 1 of the tracking issue.
        let_it_be(:shared_root) { create(:group) }
        let_it_be(:sharing_group) { create(:group) }

        before_all do
          create(:group_group_link, shared_group: shared_root, shared_with_group: sharing_group,
            group_access: Gitlab::Access::REPORTER)
          sharing_group.add_reporter(user)
        end

        before do
          stub_licensed_features(orbit: true)
        end

        it { is_expected.to be(true) }
      end

      context 'when the user is Reporter+ only through a project (no group membership)' do
        # Deliberate behavior change from the old top-level check, pending a
        # Product decision (tracked with the billing/SOX open questions on the
        # issue). The old predicate iterated `user.authorized_groups.top_level`,
        # which unions `authorized_projects` root ancestors, so a project-only
        # Reporter+ member under a licensed root WAS entitled. Path-based
        # resolution uses Search::GroupsFinder, which has no project-authorization
        # arm, so this user is now denied. This spec pins the current behavior so
        # neither direction regresses silently and the decision stays visible.
        let_it_be(:root_group) { create(:group) }
        let_it_be(:subgroup) { create(:group, parent: root_group) }
        let_it_be(:project) { create(:project, group: subgroup) }

        before_all do
          project.add_reporter(user)
        end

        before do
          stub_licensed_features(orbit: true)
        end

        it 'has the project root in authorized_groups.top_level (old check would allow)' do
          expect(user.authorized_groups.top_level).to include(root_group)
        end

        it { is_expected.to be(false) }
      end

      context 'with caching', :use_clean_rails_memory_store_caching do
        let_it_be(:group) { create(:group).tap { |g| g.add_reporter(user) } }
        let(:cache_key) { ['users', user.id, described_class::CACHE_KEY] }

        context 'when the result is positive' do
          before do
            stub_licensed_features(orbit: true)
          end

          it 'runs the expensive root resolution only once per user within the cache window' do
            # Spy on the actual expensive work (the Search::GroupsFinder query that
            # backs reporter_plus_root_namespace_ids), not the wrapper method, so
            # the assertion proves resolution is genuinely skipped on the cache hit.
            expect(::Search::GroupsFinder).to receive(:new).once.and_call_original

            2.times { described_class.available_for?(user) }
          end

          it 'caches the result with the positive TTL' do
            allow(Rails.cache).to receive(:write).and_call_original

            described_class.available_for?(user)

            expect(Rails.cache).to have_received(:write).with(
              cache_key, true, expires_in: described_class::POSITIVE_CACHE_PERIOD
            )
          end
        end

        context 'when the result is negative' do
          before do
            stub_licensed_features(orbit: false)
          end

          it 'does not rerun root resolution for a cached denied result', :aggregate_failures do
            expect(::Search::GroupsFinder).to receive(:new).once.and_call_original

            2.times { expect(described_class.available_for?(user)).to be(false) }
          end

          it 'caches the result with the negative TTL' do
            allow(Rails.cache).to receive(:write).and_call_original

            described_class.available_for?(user)

            expect(Rails.cache).to have_received(:write).with(
              cache_key, false, expires_in: described_class::NEGATIVE_CACHE_PERIOD
            )
          end
        end
      end
    end
  end

  describe '.namespace_enrollable_or_enrolled?' do
    let_it_be(:group) { create(:group) }

    subject(:enrollable) { described_class.namespace_enrollable_or_enrolled?(group) }

    context 'when :orbit_enroll_namespace is enabled for the group' do
      it { is_expected.to be(true) }
    end

    context 'when :orbit_enroll_namespace is disabled' do
      before do
        stub_feature_flags(orbit_enroll_namespace: false)
      end

      it { is_expected.to be(false) }

      context 'and the group is already enrolled' do
        before do
          create(:knowledge_graph_enabled_namespace, namespace: group)
        end

        it { is_expected.to be(true) }
      end
    end
  end
end
