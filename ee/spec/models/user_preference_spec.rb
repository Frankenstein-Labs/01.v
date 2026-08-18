# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserPreference do
  let_it_be(:user) { create(:user, :with_namespace) }

  let(:user_preference) { create(:user_preference, user: user) }

  shared_context 'with multiple user add-on assignments' do
    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:groups) { create_list(:group_with_plan, 2, plan: :ultimate_plan) }

    let_it_be(:add_on_purchases) do
      [
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: groups.first),
        create(:gitlab_subscription_add_on_purchase, namespace: groups.second, add_on: duo_pro_add_on)
      ]
    end

    let_it_be(:user_assignments) do
      add_on_purchases.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end
  end

  shared_examples 'updates roadmap_epics_state' do |state|
    it 'saves roadmap_epics_state in user_preference' do
      user_preference.update!(roadmap_epics_state: state)

      expect(user_preference.reload.roadmap_epics_state).to eq(state)
    end
  end

  describe 'associations' do
    it 'belongs to default_add_on_assignment optionally' do
      is_expected.to belong_to(:default_duo_add_on_assignment)
                       .class_name('GitlabSubscriptions::UserAddOnAssignment')
                       .optional
    end

    it 'belongs to duo_default_namespace optionally' do
      is_expected.to belong_to(:duo_default_namespace)
                       .class_name('Namespace')
                       .optional
    end
  end

  describe 'roadmap_epics_state' do
    context 'when set to open epics' do
      it_behaves_like 'updates roadmap_epics_state', Epic.available_states[:opened]
    end

    context 'when set to closed epics' do
      it_behaves_like 'updates roadmap_epics_state', Epic.available_states[:closed]
    end

    context 'when reset to all epics' do
      it_behaves_like 'updates roadmap_epics_state', nil
    end
  end

  describe '#eligible_duo_add_on_assignments', :saas do
    include_context 'with multiple user add-on assignments'

    let_it_be(:non_eligible_user_assignments) do
      non_eligible_add_on = [
        create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: create(:group)),
        create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: groups.first)
      ]

      non_eligible_add_on.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end

    let(:eligible_user_assignments) { user_assignments }

    it 'only retrieves eligible user assignments with disctinct namespaces' do
      expect(user_preference.eligible_duo_add_on_assignments).to match_array(eligible_user_assignments)
    end
  end

  describe '#distinct_eligible_duo_add_on_assignments', :saas do
    include_context 'with multiple user add-on assignments'

    let_it_be(:non_eligible_user_assignments) do
      non_eligible_add_on = [
        create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: create(:group)),
        create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: groups.second),
        create(:gitlab_subscription_add_on_purchase, namespace: groups.first, add_on: duo_pro_add_on)
      ]

      non_eligible_add_on.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end

    let(:expected_eligible_namespaces) { user_assignments.map(&:namespace) }

    it 'only retrieves eligible user assignments' do
      actual_eligible_namespaces = user_preference.distinct_eligible_duo_add_on_assignments.map(&:namespace)

      expect(actual_eligible_namespaces).to match_array(expected_eligible_namespaces)
      expect(actual_eligible_namespaces.count).to eq(2)
    end
  end

  describe 'default_duo_add_on_assignment_id', :saas do
    let_it_be(:groups) do
      create_list(:group_with_plan, 2, plan: :ultimate_plan)
    end

    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

    let_it_be(:add_on_purchases) do
      [
        create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on, namespace: groups.first),
        create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on, namespace: groups.second),
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: groups.first)
      ]
    end

    let_it_be(:user_assignments) do
      add_on_purchases.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end

    let(:first_assignment_id) { user_preference.distinct_eligible_duo_add_on_assignments.to_a.first.id }
    let(:second_assignment_id) { user_preference.distinct_eligible_duo_add_on_assignments.to_a.second.id }

    context 'when default_duo_add_on_assignment_id has not changed?' do
      it 'does call #check_seat_for_default_duo_namespace' do
        expect(user_preference).not_to receive(:check_seat_for_default_duo_assigment).and_call_original

        user_preference.valid?
      end
    end

    context 'when default_duo_add_on_assignment_id has changed?' do
      it 'calls #check_seat_for_default_duo_namespace' do
        expect(user_preference).to receive(:check_seat_for_default_duo_assigment).and_call_original

        user_preference.default_duo_add_on_assignment_id = first_assignment_id
        user_preference.valid?
      end
    end

    context 'when a correct value is assigned' do
      it 'saves the value' do
        user_preference.default_duo_add_on_assignment_id = first_assignment_id
        user_preference.save!

        expect(user_preference.default_duo_add_on_assignment_id).to eql(first_assignment_id)
      end
    end

    context 'when the seat gets destroyed' do
      it 'nullifies default duo_add_on_assignment_id' do
        user_preference.default_duo_add_on_assignment_id = first_assignment_id
        user_preference.save!

        user_assignments.first.destroy!
        user_preference.reload

        expect(user_preference.default_duo_add_on_assignment_id).to be_nil
      end
    end

    context 'when default_duo_add_on_assignment_id is changed to assignment id with namespace attached' do
      it 'does not add any errors' do
        [first_assignment_id, second_assignment_id].each do |seat_id|
          user_preference.default_duo_add_on_assignment_id = seat_id
          user_preference.valid?

          expect(user_preference.errors[:default_duo_add_on_assignment_id]).to be_empty
        end
      end
    end

    context 'when default_duo_add_on_assignment_id is changed to non_existing_id' do
      it 'does add an errors' do
        user_preference.default_duo_add_on_assignment_id = non_existing_record_id
        user_preference.valid?

        expect(user_preference.errors[:default_duo_add_on_assignment_id])
          .to include("No Duo seat assignments with namespace found with ID #{non_existing_record_id}")
      end
    end

    context 'when the assignment is not for a duo add on' do
      let(:non_duo_add_on) { create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: groups.first) }
      let(:user_assignment_id) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: non_duo_add_on, user: user).id
      end

      it 'does add an errors' do
        user_preference.default_duo_add_on_assignment_id = user_assignment_id
        user_preference.valid?

        expect(user_preference.errors[:default_duo_add_on_assignment_id])
          .to include("No Duo seat assignments with namespace found with ID #{user_assignment_id}")
      end
    end
  end

  describe 'no_eligible_duo_add_on_assignments?', :saas do
    context 'when there are multiple eligible duo add-on assignments' do
      include_context 'with multiple user add-on assignments'

      it 'returns false' do
        expect(user_preference.no_eligible_duo_add_on_assignments?).to be_falsey
      end
    end

    context 'when there is one eligible duo add-on assignment' do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }

      let_it_be(:add_on) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
      end

      let_it_be(:user_assignments) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end

      it 'returns false' do
        expect(user_preference.no_eligible_duo_add_on_assignments?).to be_falsey
      end
    end

    context 'when there are no eligible duo add-on assignments' do
      it 'returns true' do
        expect(user_preference.no_eligible_duo_add_on_assignments?).to be_truthy
      end
    end
  end

  describe '#duo_default_namespace_candidates', feature_category: :ai_abstraction_layer do
    context 'when SaaS', :saas do
      before do
        stub_saas_features(gitlab_duo_saas_only: true)
      end

      context 'when user has various duo add-on configurations' do
        def create_group(name)
          create(:group_with_plan, plan: :ultimate_plan, name: name)
        end

        let_it_be(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
        let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
        let_it_be(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

        let_it_be(:duo_credits_add_on) { create(:gitlab_subscription_add_on, :gitlab_credits) }

        let_it_be(:core_namespace) { create_group('core_namespace') }
        let_it_be(:core_expired_namespace) { create_group('core_expired_namespace') }
        let_it_be(:pro_namespace) { create_group('pro_namespace') }
        let_it_be(:enterprise_namespace) { create_group('enterprise_namespace') }
        let_it_be(:no_assignment_namespace) { create_group('no_assignment_namespace') }
        let_it_be(:credits_namespace) { create(:group, name: 'credits_namespace') }

        let_it_be(:duo_core_purchase) do
          create(:gitlab_subscription_add_on_purchase, namespace: core_namespace, add_on: duo_core_add_on)
        end

        let_it_be(:duo_pro_purchase) do
          create(:gitlab_subscription_add_on_purchase, namespace: pro_namespace, add_on: duo_pro_add_on)
        end

        let_it_be(:duo_enterprise_purchase) do
          create(:gitlab_subscription_add_on_purchase, namespace: enterprise_namespace, add_on: duo_enterprise_add_on)
        end

        let_it_be(:expired_purchase) do
          create(:gitlab_subscription_add_on_purchase, namespace: core_expired_namespace, add_on: duo_core_add_on,
            expires_on: 1.day.ago)
        end

        let_it_be(:duo_pro_purchase_no_assignment) do
          create(:gitlab_subscription_add_on_purchase, namespace: no_assignment_namespace, add_on: duo_pro_add_on)
        end

        let_it_be(:credits_purchase) do
          create(:gitlab_subscription_add_on_purchase, namespace: credits_namespace, add_on: duo_credits_add_on)
        end

        let_it_be(:pro_user_assignment) do
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: duo_pro_purchase, user: user)
        end

        let_it_be(:enterprise_user_assignment) do
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: duo_enterprise_purchase, user: user)
        end

        before do
          [
            core_namespace, pro_namespace, enterprise_namespace, no_assignment_namespace,
            core_expired_namespace, credits_namespace
          ].each { |namespace| namespace.add_developer(user) }
        end

        it 'returns namespaces with duo core, gitlab_credits, and seat-assignable add-ons with assignments' do
          result = user_preference.duo_default_namespace_candidates

          # Should include:
          # - core_namespace (duo core - membership-based, no assignment needed)
          # - credits_namespace (gitlab_credits - membership-based, no assignment needed)
          # - pro_namespace (duo pro with assignment)
          # - enterprise_namespace (duo enterprise with assignment)
          # Should NOT include:
          # - no_assignment_namespace (duo pro but no assignment)
          # - core_expired_namespace (duo core but purchase expired)
          expect(result).to match_array([core_namespace, credits_namespace, pro_namespace, enterprise_namespace])
        end
      end

      it 'is empty when user has no eligible duo add-on assignments' do
        result = user_preference.duo_default_namespace_candidates

        expect(result).to be_empty
      end
    end

    context 'when Self-Managed' do
      let_it_be(:top_level_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: top_level_group) }

      it 'returns top level authorized groups' do
        top_level_group.add_maintainer(user)
        subgroup.add_maintainer(user)

        result = user_preference.duo_default_namespace_candidates

        expect(result).to include(top_level_group)
      end
    end
  end

  describe '#duo_default_namespace_with_fallback', :saas do
    let_it_be(:namespace) { create(:group, :private, name: 'group') }
    let_it_be(:other_namespace) { create(:group, :private, name: 'other group') }

    context 'when duo_default_namespace_id is set and namespace is in candidates' do
      it 'returns the namespace when accessible' do
        namespace.add_developer(user)
        allow(user_preference).to receive(:duo_default_namespace_candidates)
          .and_return(Namespace.where(id: namespace.id))

        user_preference.duo_default_namespace = namespace

        expect(user_preference.duo_default_namespace_with_fallback).to eq(namespace)
      end
    end

    context 'when duo_default_namespace_id is set but namespace is not in candidates' do
      before do
        user_preference.duo_default_namespace_id = namespace.id
        allow(user_preference).to receive(:duo_default_namespace_candidates).and_return(Namespace.none)
      end

      it 'falls back to default_duo_add_on_assignment namespace when assignment exists', :saas do
        add_on_purchase = create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: other_namespace)
        assignment = create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
        user_preference.default_duo_add_on_assignment = assignment

        expect(user_preference.duo_default_namespace_with_fallback).to eq(other_namespace)
      end

      it 'falls back to single candidate when no assignment exists but one candidate available' do
        allow(user_preference).to receive(:duo_default_namespace_candidates)
          .and_return(Namespace.where(id: other_namespace.id))

        expect(user_preference.duo_default_namespace_with_fallback).to eq(other_namespace)
      end

      it 'returns nil when multiple candidates exist and no assignment' do
        third_namespace = create(:group)
        allow(user_preference).to receive(:duo_default_namespace_candidates).and_return(Namespace.where(id: [
          other_namespace.id, third_namespace.id
        ]))

        expect(user_preference.duo_default_namespace_with_fallback).to be_nil
      end

      it 'returns nil when no candidates exist and no assignment' do
        expect(user_preference.duo_default_namespace_with_fallback).to be_nil
      end
    end

    context 'when duo_default_namespace_id is nil' do
      before do
        user_preference.duo_default_namespace_id = nil
      end

      it 'falls back to default_duo_add_on_assignment namespace when assignment exists', :saas do
        add_on_purchase = create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
        assignment = create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
        user_preference.default_duo_add_on_assignment = assignment

        expect(user_preference.duo_default_namespace_with_fallback).to eq(namespace)
      end

      it 'falls back to single candidate when no assignment exists but one candidate available' do
        allow(user_preference).to receive(:duo_default_namespace_candidates)
          .and_return(Namespace.where(id: namespace.id))

        expect(user_preference.duo_default_namespace_with_fallback).to eq(namespace)
      end

      it 'returns nil when multiple candidates exist and no assignment' do
        allow(user_preference).to receive(:duo_default_namespace_candidates)
          .and_return(Namespace.where(id: [namespace.id, other_namespace.id]))

        expect(user_preference.duo_default_namespace_with_fallback).to be_nil
      end

      it 'returns nil when no candidates exist and no assignment' do
        allow(user_preference).to receive(:duo_default_namespace_candidates)
          .and_return(Namespace.none)

        expect(user_preference.duo_default_namespace_with_fallback).to be_nil
      end
    end

    it 'returns nil when no fallback is present', :saas do
      user_preference.duo_default_namespace_id = nil

      expect(user_preference.duo_default_namespace_with_fallback).to be_nil
    end
  end

  describe '#duo_default_namespace' do
    let_it_be(:namespace) { create(:group, :private) }

    it 'returns the namespace when accessible' do
      namespace.add_developer(user)

      user_preference.duo_default_namespace = namespace

      expect(user_preference.duo_default_namespace).to eq(namespace)
    end

    it 'returns nil when not accessible' do
      user_preference.duo_default_namespace_id = namespace.id

      expect(user_preference.duo_default_namespace).to be_nil
    end

    it 'returns nil when duo_default_namespace is nil' do
      user_preference.duo_default_namespace = nil

      expect(user_preference.duo_default_namespace).to be_nil
    end
  end

  describe '#duo_default_namespace_id=' do
    let_it_be(:namespace) { create(:group, :private) }

    def expect_assignment_id_and_namespace_id(assignment_id, namespace_id)
      expect(user_preference).to have_attributes(
        default_duo_add_on_assignment_id: assignment_id,
        duo_default_namespace_id: namespace_id
      )
    end

    context 'when setting namespace_id to a value' do
      it 'sets duo_default_namespace_id' do
        user_preference.duo_default_namespace_id = namespace.id

        expect_assignment_id_and_namespace_id(nil, namespace.id)
      end

      it 'sets duo_default_namespace_id and does not update default_duo_add_on_assignment_id' do
        user_preference.default_duo_add_on_assignment_id = 123

        user_preference.duo_default_namespace_id = namespace.id

        expect_assignment_id_and_namespace_id(123, namespace.id)
      end
    end

    context 'when setting namespace_id to nil' do
      it 'clears both duo_default_namespace_id and default_duo_add_on_assignment_id' do
        user_preference.default_duo_add_on_assignment_id = 123
        user_preference.duo_default_namespace_id = namespace.id

        user_preference.duo_default_namespace_id = nil

        expect_assignment_id_and_namespace_id(nil, nil)
      end
    end
  end

  describe '#validate_duo_default_namespace_id' do
    let_it_be(:namespace) { create(:group, :private) }

    def expect_valid(valid)
      expect(user_preference.valid?).to eq(valid)
      expect(user_preference.errors.added?(:duo_default_namespace_id, :invalid)).to be true unless valid
    end

    it 'is valid when duo_default_namespace_id is nil' do
      user_preference.duo_default_namespace_id = nil

      expect_valid(true)
    end

    it 'is valid when user has read access to the namespace' do
      namespace.add_developer(user)
      user_preference.duo_default_namespace_id = namespace.id

      expect_valid(true)
    end

    it 'adds error when user does not have read access to the namespace' do
      user_preference.duo_default_namespace_id = namespace.id

      expect_valid(false)
    end

    it 'adds error when duo_default_namespace is set directly instead of duo_default_namespace_id' do
      user_preference.duo_default_namespace = namespace

      expect_valid(false)
    end
  end

  describe 'orbit_settings', feature_category: :duo_agent_platform do
    describe 'validations' do
      it 'validates json schema' do
        user_preference.orbit_settings = { 'enabled' => true }
        expect(user_preference).to be_valid

        user_preference.orbit_settings = { 'enabled' => false }
        expect(user_preference).to be_valid

        user_preference.orbit_settings = {
          'enabled' => true,
          'orbit_agent_enabled' => false,
          'orbit_agentic_chat_enabled' => true,
          'orbit_other_foundational_agents_enabled' => false,
          'orbit_custom_agents_enabled' => true
        }
        expect(user_preference).to be_valid

        user_preference.orbit_settings = { 'invalid_key' => 'value' }
        expect(user_preference).not_to be_valid
        expect(user_preference.errors[:orbit_settings]).to include('must be a valid json schema')

        user_preference.orbit_settings = { 'enabled' => 'not_boolean' }
        expect(user_preference).not_to be_valid
        expect(user_preference.errors[:orbit_settings]).to include('must be a valid json schema')

        user_preference.orbit_settings = { 'orbit_agent_enabled' => 'not_boolean' }
        expect(user_preference).not_to be_valid
        expect(user_preference.errors[:orbit_settings]).to include('must be a valid json schema')
      end

      it 'allows empty object' do
        user_preference.orbit_settings = {}
        expect(user_preference).to be_valid
      end

      it 'has default empty hash' do
        new_preference = described_class.new(user: user)
        expect(new_preference.orbit_settings).to eq({})
      end

      it 'persists changes correctly' do
        user_preference.update!(orbit_settings: { 'enabled' => false })

        expect(user_preference.reload.orbit_settings).to eq({ 'enabled' => false })
      end
    end

    describe '#orbit_enabled' do
      it 'returns false when orbit_settings is empty (default opt-out)' do
        user_preference.orbit_settings = {}
        expect(user_preference.orbit_enabled).to be(false)
      end

      it 'returns true when enabled is explicitly true' do
        user_preference.orbit_settings = { 'enabled' => true }
        expect(user_preference.orbit_enabled).to be(true)
      end

      it 'returns false when enabled is explicitly false' do
        user_preference.orbit_settings = { 'enabled' => false }
        expect(user_preference.orbit_enabled).to be(false)
      end
    end

    describe '#orbit_enabled=' do
      it 'sets enabled in orbit_settings' do
        user_preference.orbit_enabled = false
        expect(user_preference.orbit_settings).to eq({ 'enabled' => false })
      end

      it 'merges into existing orbit_settings' do
        user_preference.orbit_settings = { 'enabled' => true }
        user_preference.orbit_enabled = false
        expect(user_preference.orbit_settings).to eq({ 'enabled' => false })
      end

      it 'preserves subsetting keys when toggling the killswitch' do
        user_preference.orbit_settings = {
          'enabled' => true,
          'orbit_agent_enabled' => false,
          'orbit_agentic_chat_enabled' => true
        }

        user_preference.orbit_enabled = false

        expect(user_preference.orbit_settings).to eq(
          'enabled' => false,
          'orbit_agent_enabled' => false,
          'orbit_agentic_chat_enabled' => true
        )
      end
    end

    describe 'subsetting accessors' do
      using RSpec::Parameterized::TableSyntax

      where(:subsetting) { described_class::ORBIT_SUBSETTINGS.map { |s| [s] } }

      with_them do
        it 'returns false when the main killswitch is off, regardless of stored value' do
          user_preference.orbit_settings = { 'enabled' => false, subsetting => true }

          expect(user_preference.public_send(subsetting)).to be(false)
        end

        it 'defaults to true when the main killswitch is on but subsetting key is absent' do
          user_preference.orbit_settings = { 'enabled' => true }

          expect(user_preference.public_send(subsetting)).to be(true)
        end

        it 'returns the stored value when the main killswitch is on' do
          user_preference.orbit_settings = { 'enabled' => true, subsetting => false }

          expect(user_preference.public_send(subsetting)).to be(false)
        end

        it 'persists changes via the writer and merges into orbit_settings' do
          user_preference.orbit_settings = { 'enabled' => true }
          user_preference.public_send(:"#{subsetting}=", false)

          expect(user_preference.orbit_settings).to include('enabled' => true, subsetting => false)
        end

        it 'casts non-boolean values to boolean' do
          user_preference.orbit_settings = { 'enabled' => true }
          user_preference.public_send(:"#{subsetting}=", '1')

          expect(user_preference.orbit_settings[subsetting]).to be(true)

          user_preference.public_send(:"#{subsetting}=", '0')

          expect(user_preference.orbit_settings[subsetting]).to be(false)
        end
      end
    end
  end

  describe '#knowledge_graph_governing_namespace_with_fallback', :saas, feature_category: :knowledge_graph do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it 'returns nil when no eligible candidates exist' do
      expect(user_preference.knowledge_graph_governing_namespace_with_fallback).to be_nil
    end

    context 'with one eligible candidate' do
      let_it_be(:eligible_group) { create_orbit_billable_group(user) }

      it 'returns the stored namespace when stored id is eligible' do
        user_preference.update!(knowledge_graph_governing_namespace_id: eligible_group.id)

        expect(user_preference.knowledge_graph_governing_namespace_with_fallback).to eq(eligible_group)
      end

      it 'returns the sole candidate via fallback when stored id is nil' do
        eligible_group # touch to ensure created

        expect(user_preference.knowledge_graph_governing_namespace_with_fallback).to eq(eligible_group)
      end

      it 'falls back to the sole candidate when stored id points to an ineligible namespace' do
        ineligible_subgroup = create(:group, parent: eligible_group)
        user_preference.update_column(:knowledge_graph_governing_namespace_id, ineligible_subgroup.id)

        expect(user_preference.knowledge_graph_governing_namespace_with_fallback).to eq(eligible_group)
      end
    end

    context 'when authorized group has Orbit disabled' do
      let(:group_without_orbit) do
        create(:group, owners: user).tap do |g|
          create(:gitlab_subscription, :premium, namespace: g)
        end
      end

      it 'returns nil even though the user is a member of the group' do
        group_without_orbit # touch to ensure created

        expect(user_preference.knowledge_graph_governing_namespace_with_fallback).to be_nil
      end
    end

    context 'with multiple eligible candidates' do
      let_it_be(:group_a) { create_orbit_billable_group(user) }
      let_it_be(:group_b) { create_orbit_billable_group(user) }

      it 'returns the stored namespace when stored id matches one' do
        group_b # touch to ensure created
        user_preference.update!(knowledge_graph_governing_namespace_id: group_a.id)

        expect(user_preference.knowledge_graph_governing_namespace_with_fallback).to eq(group_a)
      end

      it 'returns nil when stored id is nil (no single fallback)' do
        group_a
        group_b

        expect(user_preference.knowledge_graph_governing_namespace_with_fallback).to be_nil
      end
    end
  end

  describe '#knowledge_graph_governing_namespace', :saas, feature_category: :knowledge_graph do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    let_it_be(:eligible_group) { create_orbit_billable_group(user) }

    it 'returns nil when no namespace is stored' do
      user_preference.knowledge_graph_governing_namespace_id = nil

      expect(user_preference.knowledge_graph_governing_namespace).to be_nil
    end

    it 'returns the namespace when the stored id is eligible' do
      user_preference.update!(knowledge_graph_governing_namespace_id: eligible_group.id)

      expect(user_preference.knowledge_graph_governing_namespace).to eq(eligible_group)
    end

    it 'returns nil when the stored id is no longer eligible' do
      ineligible_subgroup = create(:group, parent: eligible_group)
      user_preference.update_column(:knowledge_graph_governing_namespace_id, ineligible_subgroup.id)

      expect(user_preference.knowledge_graph_governing_namespace).to be_nil
    end

    it 'returns nil when the stored namespace no longer has Orbit enabled' do
      user_preference.update!(knowledge_graph_governing_namespace_id: eligible_group.id)
      eligible_group.knowledge_graph_enabled_namespace.destroy!

      expect(user_preference.reload.knowledge_graph_governing_namespace).to be_nil
    end
  end

  describe '#validate_knowledge_graph_governing_namespace_id', :saas, feature_category: :knowledge_graph do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    let_it_be(:eligible_group) { create_orbit_billable_group(user) }

    def expect_valid(valid)
      expect(user_preference.valid?).to eq(valid)
      expect(user_preference.errors.added?(:knowledge_graph_governing_namespace_id, :invalid)).to be true unless valid
    end

    it 'is valid when knowledge_graph_governing_namespace_id is nil' do
      user_preference.knowledge_graph_governing_namespace_id = nil

      expect_valid(true)
    end

    it 'is valid when the namespace is eligible' do
      user_preference.knowledge_graph_governing_namespace_id = eligible_group.id

      expect_valid(true)
    end

    it 'adds error when the namespace is not eligible' do
      ineligible_subgroup = create(:group, parent: eligible_group)
      user_preference.knowledge_graph_governing_namespace_id = ineligible_subgroup.id

      expect_valid(false)
    end

    it 'adds error when the namespace does not have Orbit enabled' do
      group_without_orbit = create(:group, owners: user).tap do |g|
        create(:gitlab_subscription, :premium, namespace: g)
      end
      user_preference.knowledge_graph_governing_namespace_id = group_without_orbit.id

      expect_valid(false)
    end

    it 'adds error when the namespace has Orbit enabled but no paid plan' do
      group_without_plan = create(:group, owners: user).tap do |g|
        create(:knowledge_graph_enabled_namespace, namespace: g)
      end
      user_preference.knowledge_graph_governing_namespace_id = group_without_plan.id

      expect_valid(false)
    end
  end

  def create_orbit_billable_group(user)
    create(:group, owners: user).tap do |g|
      create(:gitlab_subscription, :premium, namespace: g)
      create(:knowledge_graph_enabled_namespace, namespace: g)
    end
  end
end
