# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::Custom::Type, feature_category: :team_planning do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:namespace) { create(:group) }

  describe 'validations' do
    subject(:work_item_custom_type) { build(:work_item_custom_type) }

    describe 'single_parent_set' do
      context 'when neither organization nor namespace is set' do
        subject(:work_item_custom_type) { build(:work_item_custom_type, organization: nil, namespace: nil) }

        it 'is invalid' do
          expect(work_item_custom_type).to be_invalid
          expect(work_item_custom_type.errors[:base]).to include(
            'Exactly one of namespace_id, organization_id must be present'
          )
        end
      end

      context 'when both organization and namespace are set' do
        before do
          work_item_custom_type.organization = organization
          work_item_custom_type.namespace = namespace
        end

        it 'is invalid' do
          expect(work_item_custom_type).to be_invalid
        end
      end

      context 'when only organization is set' do
        subject { build(:work_item_custom_type, organization: create(:organization), namespace: nil) }

        it { is_expected.to be_valid }
      end

      context 'when only namespace is set' do
        subject { build(:work_item_custom_type, organization: nil, namespace: create(:group)) }

        it { is_expected.to be_valid }
      end
    end

    describe 'name uniqueness' do
      context 'when scoped to organization' do
        before do
          create(:work_item_custom_type, :with_organization, organization: organization, name: 'Feature')
        end

        it 'validates uniqueness within the same organization' do
          duplicate = build(:work_item_custom_type, :with_organization, organization: organization, name: 'Feature')
          expect(duplicate).to be_invalid
          expect(duplicate.errors[:name]).to include('has already been taken')
        end

        it 'allows same name in different organization' do
          other_org = create(:organization)
          type = build(:work_item_custom_type, :with_organization, organization: other_org, name: 'Feature')
          expect(type).to be_valid
        end
      end

      context 'when scoped to namespace' do
        before do
          create(:work_item_custom_type, namespace: namespace, name: 'Feature')
        end

        it 'validates uniqueness within the same namespace' do
          duplicate = build(:work_item_custom_type, namespace: namespace, name: 'Feature')
          expect(duplicate).to be_invalid
          expect(duplicate.errors[:name]).to include('has already been taken')
        end

        it 'allows same name in different namespace' do
          other_namespace = create(:group)
          type = build(:work_item_custom_type, namespace: other_namespace, name: 'Feature')
          expect(type).to be_valid
        end
      end
    end

    describe 'reserved names' do
      described_class::RESERVED_NAMES.each do |reserved_name|
        it "prevents using reserved name '#{reserved_name}'" do
          type = build(:work_item_custom_type, :with_organization, organization: organization, name: reserved_name)

          expect(type).to be_invalid
          expect(type.errors[:name]).to include(/is a reserved name and cannot be used/)
        end
      end

      it 'prevents using reserved names with spaces instead of underscores' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'Merge Request')

        expect(type).to be_invalid
        expect(type.errors[:name]).to include("'Merge Request' is a reserved name and cannot be used.")
      end

      it 'prevents using reserved names with multiple spaces' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'Merge  Request')

        expect(type).to be_invalid
        expect(type.errors[:name]).to include("'Merge Request' is a reserved name and cannot be used.")
      end

      it 'prevents using reserved names with hyphens instead of underscores' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'Merge-Request')

        expect(type).to be_invalid
        expect(type.errors[:name]).to include("'Merge Request' is a reserved name and cannot be used.")
      end

      it 'validates reserved names case-insensitively' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'VULNERABILITY')

        expect(type).to be_invalid
        expect(type.errors[:name]).to include("'Vulnerability' is a reserved name and cannot be used.")
      end

      it 'allows non-reserved names' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'Feature')

        expect(type).to be_valid
      end
    end

    describe 'icon_name' do
      let(:valid_icon_names) { described_class.icon_names.keys.sort.join(', ') }

      it 'prevents blank icon_name' do
        type = build(:work_item_custom_type, namespace: namespace, icon_name: nil)

        expect(type).to be_invalid
        expect(type.errors[:icon_name]).to include("can't be blank")
      end

      it 'prevents invalid icon_name' do
        type = build(:work_item_custom_type, namespace: namespace)
        type.icon_name = 'invalid_icon'

        expect(type).to be_invalid
        expect(type.errors[:icon_name]).to include("is not valid. Valid icon names are: #{valid_icon_names}")
      end

      it 'allows valid icon_name' do
        type = build(:work_item_custom_type, namespace: namespace, icon_name: 'bug')

        expect(type).to be_valid
      end
    end

    describe 'name uniqueness against system-defined types' do
      it 'prevents using system-defined type names' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'Task')

        expect(type).to be_invalid
        expect(type.errors[:name]).to include("'Task' is already taken.")
      end

      it 'validates system-defined type names case-insensitively' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'TASK')

        expect(type).to be_invalid
        expect(type.errors[:name]).to include("'Task' is already taken.")
      end

      it 'validates system-defined type names with extra spaces' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'Test   Case')

        expect(type).to be_invalid
        expect(type.errors[:name]).to include("'Test Case' is already taken.")
      end

      it 'validates system-defined type names with hyphens' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'Test-Case')

        expect(type).to be_invalid
        expect(type.errors[:name]).to include("'Test Case' is already taken.")
      end

      it 'allows names that are not system-defined' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: 'Feature')
        expect(type).to be_valid
      end

      it 'skips validation when name is blank' do
        type = build(:work_item_custom_type, :with_organization, organization: organization, name: '')
        type.valid?
        expect(type.errors[:name]).to include("can't be blank")
      end

      context 'when converted from system-defined type' do
        it 'allows keeping the same name as the system-defined type' do
          type = build(:work_item_custom_type, :converted_from_issue, :with_organization, organization: organization,
            name: 'Issue')
          expect(type).to be_valid
        end

        it 'allows keeping the same name with different casing' do
          type = build(:work_item_custom_type, :converted_from_incident, :with_organization,
            organization: organization, name: 'INCIDENT')
          expect(type).to be_valid
        end

        it 'prevents renaming to a different system-defined type name' do
          type = build(:work_item_custom_type, :converted_from_task, :with_organization, organization: organization,
            name: 'Issue')
          expect(type).to be_invalid
          expect(type.errors[:name]).to include("'Issue' is already taken.")
        end

        it 'allows renaming to a non-system-defined name' do
          type = build(:work_item_custom_type, :converted_from_task, :with_organization, organization: organization,
            name: 'Feature')
          expect(type).to be_valid
        end

        context 'when another converted type with changed name exists' do
          before do
            create(:work_item_custom_type, :converted_from_issue, :with_organization,
              organization: organization, name: 'Custom Issue')
          end

          it 'allows reusing the system-defined name of the existing converted type' do
            type = build(:work_item_custom_type, :converted_from_task, :with_organization,
              organization: organization, name: 'Issue')
            expect(type).to be_valid
          end
        end
      end
    end

    describe 'max types per parent limit' do
      let(:available_types_count) do
        provider = WorkItems::TypesFramework::Provider.new(parent_for_provider)
        provider.available_system_defined_types_count
      end

      shared_examples 'validates max types per parent limit' do |parent_attribute|
        before do
          stub_licensed_features(epics: true, requirements: true)
          stub_feature_flags(okrs_mvc: true)
          stub_const("#{described_class}::MAX_TYPE_PER_PARENT", available_types_count)
        end

        it 'is invalid when exceeding maximum allowed types' do
          type = build(:work_item_custom_type, **parent_params)

          expect(type).to be_invalid
          expect(type.errors[parent_attribute]).to include(
            "can only have a maximum of #{available_types_count} work item types."
          )
        end

        it 'allows updating existing types without hitting the limit' do
          existing_type.name = 'Updated Name'

          expect(existing_type).to be_valid
        end

        context 'when converting a system-defined type' do
          it 'does not change the total count' do
            existing_type.update!(archived: true)

            converted_type = build(:work_item_custom_type, :converted_from_issue, name: 'Custom Issue', **parent_params)

            expect(converted_type).to be_valid
          end
        end

        context 'when a converted system-defined type is archived' do
          it 'frees up a slot for a new custom type' do
            existing_type.update!(archived: true)
            create(:work_item_custom_type, :converted_from_issue, :archived, name: 'Archived Issue', **parent_params)

            new_type = build(:work_item_custom_type, **parent_params)

            expect(new_type).to be_valid
          end
        end
      end

      context 'for organization' do
        let!(:existing_type) { create(:work_item_custom_type, :with_organization, organization: organization) }
        let(:parent_params) { { organization: organization, namespace: nil } }
        let(:parent_for_provider) { organization }

        it_behaves_like 'validates max types per parent limit', :organization

        context 'when some system-defined types are unavailable' do
          let(:all_types_count) { WorkItems::TypesFramework::Provider.new.all.count }

          it 'does not count unavailable types toward the limit' do
            stub_licensed_features(epics: false, requirements: false)
            stub_feature_flags(okrs_mvc: false)

            provider = WorkItems::TypesFramework::Provider.new(organization)
            available_count = provider.available_system_defined_types_count

            expect(available_count).to be < all_types_count

            stub_const("#{described_class}::MAX_TYPE_PER_PARENT", all_types_count)

            new_type = build(:work_item_custom_type, :with_organization, organization: organization)
            expect(new_type).to be_valid
          end
        end
      end

      context 'for namespace' do
        let!(:existing_type) { create(:work_item_custom_type, namespace: namespace) }
        let(:parent_params) { { namespace: namespace } }
        let(:parent_for_provider) { namespace }

        it_behaves_like 'validates max types per parent limit', :namespace
      end
    end

    describe 'unarchiving within limit' do
      let(:available_types_count) do
        provider = WorkItems::TypesFramework::Provider.new(parent_for_provider)
        provider.available_system_defined_types_count
      end

      shared_examples 'validates unarchiving within limit' do
        before do
          stub_licensed_features(epics: true, requirements: true)
          stub_feature_flags(okrs_mvc: true)
        end

        it 'prevents unarchiving when limit is reached' do
          archived_type = create(:work_item_custom_type, :archived, **parent_params)

          stub_const("#{described_class}::MAX_TYPE_PER_PARENT", available_types_count)
          archived_type.archived = false

          expect(archived_type).to be_invalid
          expect(archived_type.errors[:base]).to include(
            "Cannot unarchive because the maximum limit of #{available_types_count} " \
              "work item types has been reached."
          )
        end

        it 'allows unarchiving when under the limit' do
          archived_type = create(:work_item_custom_type, :archived, **parent_params)

          stub_const("#{described_class}::MAX_TYPE_PER_PARENT", available_types_count + 1)
          archived_type.archived = false

          expect(archived_type).to be_valid
        end

        it 'does not count archived types towards the limit' do
          archived_type = create(:work_item_custom_type, :archived, **parent_params)

          stub_const("#{described_class}::MAX_TYPE_PER_PARENT", available_types_count)
          new_type = build(:work_item_custom_type, **parent_params.merge(organization: archived_type.organization))

          expect(new_type).to be_valid
        end

        it 'allows archiving without checking the limit' do
          active_type = create(:work_item_custom_type, **parent_params)

          stub_const("#{described_class}::MAX_TYPE_PER_PARENT", available_types_count)
          active_type.archived = true

          expect(active_type).to be_valid
        end
      end

      context 'for organization' do
        let(:parent_params) { { organization: organization, namespace: nil } }
        let(:parent_for_provider) { organization }

        it_behaves_like 'validates unarchiving within limit'
      end

      context 'for namespace' do
        let(:parent_params) { { namespace: namespace } }
        let(:parent_for_provider) { namespace }

        it_behaves_like 'validates unarchiving within limit'
      end
    end
  end

  describe 'scopes' do
    describe '.for_organization' do
      before do
        create(:work_item_custom_type, :with_organization, organization: organization, name: 'Type 1')
        create(:work_item_custom_type, :with_organization, name: 'Type 2')
        create(:work_item_custom_type, namespace: namespace, name: 'Type 3')
      end

      it 'returns only types for the given organization' do
        types = described_class.for_organization(organization)
        expect(types.pluck(:name)).to contain_exactly('Type 1')
      end
    end

    describe '.for_namespace' do
      before do
        create(:work_item_custom_type, namespace: namespace, name: 'Type 1')
        create(:work_item_custom_type, namespace: create(:group), name: 'Type 2')
        create(:work_item_custom_type, :with_organization, name: 'Type 3')
      end

      it 'returns only types for the given namespace' do
        types = described_class.for_namespace(namespace)
        expect(types.pluck(:name)).to contain_exactly('Type 1')
      end
    end

    describe '.order_by_name_asc' do
      let_it_be(:org) { create(:organization) }

      before do
        create(:work_item_custom_type, :with_organization, organization: org, name: 'Zebra')
        create(:work_item_custom_type, :with_organization, organization: org, name: 'apple')
        create(:work_item_custom_type, :with_organization, organization: org, name: 'Banana')
      end

      it 'orders by name case-insensitively' do
        names = described_class.for_organization(org).order_by_name_asc.pluck(:name)
        expect(names).to eq(%w[apple Banana Zebra])
      end
    end

    describe '.active' do
      before do
        create(:work_item_custom_type, :with_organization, organization: organization, name: 'Active Type')
        create(:work_item_custom_type, :archived, :with_organization, organization: organization, name: 'Archived Type')
      end

      it 'returns only non-archived types' do
        names = described_class.for_organization(organization).active.pluck(:name)
        expect(names).to contain_exactly('Active Type')
      end
    end
  end

  describe '#parent' do
    context 'when organization is set' do
      let(:type) { create(:work_item_custom_type, :with_organization) }

      it 'returns the organization' do
        expect(type.parent).to eq(type.organization)
      end
    end

    context 'when namespace is set' do
      let(:type) { create(:work_item_custom_type, namespace: namespace) }

      it 'returns the namespace' do
        expect(type.parent).to eq(namespace)
      end
    end
  end

  describe '#delegation_source' do
    context 'when converted from system-defined type' do
      let(:type) do
        create(:work_item_custom_type,
          converted_from_system_defined_type_identifier: 2)
      end

      it 'returns the system-defined type' do
        expect(type.base_type).to eq("incident")
      end
    end

    context 'when new custom type' do
      let(:type) { create(:work_item_custom_type) }

      it 'defaults to issue base type' do
        expect(type.base_type).to eq("issue")
      end
    end
  end

  describe '#strip_whitespaces' do
    it 'strips whitespaces from name' do
      work_item_custom_type = build(:work_item_custom_type, name: '  Feature  ')

      work_item_custom_type.valid?

      expect(work_item_custom_type.name).to eq("Feature")
    end
  end

  describe '#to_global_id' do
    context 'when converted from system-defined type' do
      let(:issue_system_type) { ::WorkItems::TypesFramework::Provider.new.find_by_base_type(:issue) }
      let(:type) { create(:work_item_custom_type, :converted_from_issue) }

      it 'returns WorkItems::Type GID with the system-defined type ID' do
        gid = type.to_global_id

        expect(gid.model_name).to eq('WorkItems::Type')
        expect(gid.model_id.to_i).to eq(issue_system_type.id)
      end
    end

    context 'when new custom type' do
      let(:type) { create(:work_item_custom_type) }

      it 'returns WorkItems::Type GID with the custom type ID' do
        gid = type.to_global_id
        expect(gid.model_name).to eq('WorkItems::Type')
        expect(gid.model_id.to_i).to eq(type.id)
      end
    end
  end

  describe 'base_type predicate methods' do
    let(:custom_type) { create(:work_item_custom_type) }

    it 'delegates all base_type predicates to the delegation source' do
      ::WorkItems::TypesFramework::Provider.new.all.each do |system_type| # rubocop:disable Rails/FindEach -- not an ActiveRecord::Relation
        predicate = :"#{system_type.base_type}?"

        expect(custom_type).to respond_to(predicate)
      end
    end

    context 'when not converted (defaults to issue delegation source)' do
      it 'returns true for issue? and false for all others' do
        expect(custom_type.issue?).to be(true)

        non_issue_types = ::WorkItems::TypesFramework::Provider.new.all.reject(&:issue?)
        non_issue_types.each do |system_type|
          expect(custom_type.public_send(:"#{system_type.base_type}?")).to be(false)
        end
      end
    end

    context 'when converted from incident' do
      let(:converted_type) { create(:work_item_custom_type, :converted_from_incident) }

      it 'returns true for incident? and false for issue?' do
        expect(converted_type.incident?).to be(true)
        expect(converted_type.issue?).to be(false)
      end
    end
  end

  describe '#non_converted_custom_type?' do
    context 'when not converted from a system-defined type' do
      let(:custom_type) { create(:work_item_custom_type) }

      it { expect(custom_type.non_converted_custom_type?).to be(true) }
    end

    context 'when converted from a system-defined type' do
      let(:converted_type) { create(:work_item_custom_type, :converted_from_incident) }

      it { expect(converted_type.non_converted_custom_type?).to be(false) }
    end
  end

  describe '#persistable_id' do
    context 'when not converted from a system-defined type' do
      let(:custom_type) { create(:work_item_custom_type) }

      it 'returns the custom type id' do
        expect(custom_type.persistable_id).to eq(custom_type.id)
      end
    end

    context 'when converted from a system-defined type' do
      let(:converted_type) { create(:work_item_custom_type, :converted_from_issue) }

      it 'returns the converted_from_system_defined_type_identifier' do
        expect(converted_type.persistable_id).to eq(converted_type.converted_from_system_defined_type_identifier)
      end

      it 'returns the system-defined type id, not the custom type AR id' do
        expect(converted_type.persistable_id).not_to eq(converted_type.id)
        expect(converted_type.persistable_id).to eq(1) # Issue type ID
      end
    end
  end

  describe '#system_defined_type_id' do
    context 'when not converted from a system-defined type' do
      let(:custom_type) { create(:work_item_custom_type) }

      it 'returns the default issue type id' do
        expect(custom_type.system_defined_type_id)
          .to eq(::WorkItems::TypesFramework::Provider.new.default_issue_type.id)
      end
    end

    context 'when converted from the Issue system-defined type' do
      let(:converted_type) { create(:work_item_custom_type, :converted_from_issue) }

      it { expect(converted_type.system_defined_type_id).to eq(1) }
    end

    context 'when converted from the Incident system-defined type' do
      let(:converted_type) { create(:work_item_custom_type, :converted_from_incident) }

      it { expect(converted_type.system_defined_type_id).to eq(2) }
    end

    context 'when converted from the Task system-defined type' do
      let(:converted_type) { create(:work_item_custom_type, :converted_from_task) }

      it { expect(converted_type.system_defined_type_id).to eq(5) }
    end
  end

  describe 'enum' do
    it 'defines icon_name enum' do
      type = create(:work_item_custom_type, icon_name: 'work-item-feature')
      expect(type.icon_name).to eq('work-item-feature')
    end
  end

  describe 'for lifecycles' do
    let_it_be(:lifecycle_namespace) { create(:group) }
    let_it_be(:other_namespace) { create(:group) }
    let_it_be(:custom_type_with_converted_from) do
      create(:work_item_custom_type, :converted_from_issue, namespace: lifecycle_namespace)
    end

    let_it_be(:custom_type) { create(:work_item_custom_type, namespace: lifecycle_namespace) }
    let_it_be(:system_defined_lifecycle) { build(:work_item_system_defined_lifecycle) }

    before do
      stub_licensed_features(work_item_status: true)
      allow_any_instance_of(WorkItems::TypeCustomLifecycle).to receive(:valid?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf -- needed to bypass HasType validation for custom type IDs
    end

    describe '#status_lifecycle_for' do
      subject(:status_lifecycle) { custom_type.status_lifecycle_for(namespace_param_id) }

      context 'when custom lifecycle exists for the custom type' do
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: lifecycle_namespace) }
        let(:namespace_param_id) { lifecycle_namespace.id }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type.id,
            namespace: lifecycle_namespace,
            lifecycle: custom_lifecycle)
        end

        it 'returns the custom lifecycle' do
          expect(status_lifecycle).to eq(custom_lifecycle)
        end
      end

      context 'when custom lifecycle exists only for the converted_from_system_defined_type' do
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: lifecycle_namespace) }
        let(:namespace_param_id) { lifecycle_namespace.id }

        subject(:status_lifecycle) { custom_type_with_converted_from.status_lifecycle_for(namespace_param_id) }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type_with_converted_from.converted_from_system_defined_type_identifier,
            namespace: lifecycle_namespace,
            lifecycle: custom_lifecycle)
        end

        it 'returns the custom lifecycle from converted_from_system_defined_type' do
          expect(status_lifecycle).to eq(custom_lifecycle)
        end
      end

      context 'when no custom lifecycle exists' do
        let(:namespace_param_id) { lifecycle_namespace.id }

        it 'returns the system-defined lifecycle' do
          expect(status_lifecycle).to eq(system_defined_lifecycle)
        end
      end

      context 'when namespace_param_id is nil' do
        let(:namespace_param_id) { nil }

        it 'returns the system-defined lifecycle' do
          expect(status_lifecycle).to eq(system_defined_lifecycle)
        end
      end

      context 'when custom lifecycle exists in a different namespace than the param' do
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: lifecycle_namespace) }
        let(:namespace_param_id) { other_namespace.id }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type.id,
            namespace: lifecycle_namespace,
            lifecycle: custom_lifecycle)
        end

        it 'returns the system-defined lifecycle' do
          expect(status_lifecycle).to eq(system_defined_lifecycle)
        end
      end
    end

    describe '#custom_lifecycle_for' do
      subject(:custom_lifecycle_result) { custom_type.custom_lifecycle_for(namespace_param_id) }

      context 'when custom lifecycle exists for the custom type id' do
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: lifecycle_namespace) }
        let(:namespace_param_id) { lifecycle_namespace.id }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type.id,
            namespace: lifecycle_namespace,
            lifecycle: custom_lifecycle)
        end

        it 'returns the custom lifecycle' do
          expect(custom_lifecycle_result).to eq(custom_lifecycle)
        end
      end

      context 'when custom lifecycle exists only for the converted_from_system_defined_type_identifier' do
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: lifecycle_namespace) }
        let(:namespace_param_id) { lifecycle_namespace.id }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type_with_converted_from.converted_from_system_defined_type_identifier,
            namespace: lifecycle_namespace,
            lifecycle: custom_lifecycle)
        end

        subject(:custom_lifecycle_result) { custom_type_with_converted_from.custom_lifecycle_for(namespace_param_id) }

        it 'returns the custom lifecycle from converted_from_system_defined_type' do
          expect(custom_lifecycle_result).to eq(custom_lifecycle)
        end
      end

      context 'when custom lifecycle exists for both custom type and converted_from_system_defined_type' do
        let_it_be(:custom_lifecycle_for_custom_type) do
          create(:work_item_custom_lifecycle, namespace: lifecycle_namespace)
        end

        let_it_be(:custom_lifecycle_for_system_type) do
          create(:work_item_custom_lifecycle, namespace: lifecycle_namespace, name: 'System Type Lifecycle')
        end

        let(:namespace_param_id) { lifecycle_namespace.id }

        subject(:custom_lifecycle_result) { custom_type_with_converted_from.custom_lifecycle_for(namespace_param_id) }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type_with_converted_from.id,
            namespace: lifecycle_namespace,
            lifecycle: custom_lifecycle_for_custom_type)
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type_with_converted_from.converted_from_system_defined_type_identifier,
            namespace: lifecycle_namespace,
            lifecycle: custom_lifecycle_for_system_type)
        end

        it 'prioritizes the converted_from_system_defined_type lifecycle' do
          expect(custom_lifecycle_result).to eq(custom_lifecycle_for_system_type)
        end
      end

      context 'when no custom lifecycle exists' do
        let(:namespace_param_id) { lifecycle_namespace.id }

        it 'returns nil' do
          expect(custom_lifecycle_result).to be_nil
        end
      end

      context 'when custom type has no converted_from_system_defined_type' do
        subject(:custom_lifecycle_result) do
          custom_type.custom_lifecycle_for(namespace_param_id)
        end

        let(:namespace_param_id) { lifecycle_namespace.id }

        context 'when custom lifecycle exists for the custom type' do
          let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: lifecycle_namespace) }

          before do
            create(:work_item_type_custom_lifecycle,
              work_item_type_id: custom_type.id,
              namespace: lifecycle_namespace,
              lifecycle: custom_lifecycle)
          end

          it 'returns the custom lifecycle' do
            expect(custom_lifecycle_result).to eq(custom_lifecycle)
          end
        end

        context 'when no custom lifecycle exists' do
          it 'returns nil' do
            expect(custom_lifecycle_result).to be_nil
          end
        end
      end

      context 'when custom lifecycle exists for a different namespace' do
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: other_namespace) }
        let(:namespace_param_id) { lifecycle_namespace.id }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type.id,
            namespace: other_namespace,
            lifecycle: custom_lifecycle)
        end

        it 'returns nil' do
          expect(custom_lifecycle_result).to be_nil
        end
      end

      context 'when namespace_param_id is nil' do
        let(:namespace_param_id) { nil }

        it 'returns nil' do
          expect(custom_lifecycle_result).to be_nil
        end
      end
    end
  end

  describe '#widget_definitions' do
    let_it_be(:issue_system_type) { ::WorkItems::TypesFramework::Provider.new.find_by_base_type(:issue) }
    let_it_be(:incident_system_type) { ::WorkItems::TypesFramework::Provider.new.find_by_base_type(:incident) }

    context 'when converted from system-defined type' do
      let(:custom_type) { create(:work_item_custom_type, :converted_from_incident) }

      it 'returns widget definitions with converted_from_system_defined_type_identifier as work_item_type_id' do
        widget_definitions = custom_type.widget_definitions

        expect(widget_definitions).to all(
          have_attributes(work_item_type_id: custom_type.converted_from_system_defined_type_identifier)
        )
      end

      it 'returns the same widget types as the delegation source' do
        delegation_source_widget_types = custom_type.delegation_source.widget_definitions.map(&:widget_type)

        expect(custom_type.widget_definitions.map(&:widget_type)).to match_array(delegation_source_widget_types)
      end
    end

    context 'when not converted (new custom type)' do
      let(:custom_type) { create(:work_item_custom_type) }

      it 'returns widget definitions with the custom type id as work_item_type_id' do
        widget_definitions = custom_type.widget_definitions

        expect(widget_definitions).to all(have_attributes(work_item_type_id: custom_type.id))
      end

      it 'returns the same widget types as the default issue delegation source' do
        delegation_source_widget_types = issue_system_type.widget_definitions.map(&:widget_type)

        expect(custom_type.widget_definitions.map(&:widget_type)).to match_array(delegation_source_widget_types)
      end
    end

    context 'when multiple custom types share the same delegation source' do
      let(:custom_type_1) { create(:work_item_custom_type, name: 'Feature') }
      let(:custom_type_2) { create(:work_item_custom_type, name: 'Bug') }

      it 'generates unique IDs for each custom type widget definitions' do
        widgets_1 = custom_type_1.widget_definitions
        widgets_2 = custom_type_2.widget_definitions

        ids_1 = widgets_1.map(&:id)
        ids_2 = widgets_2.map(&:id)

        expect(ids_1).not_to match_array(ids_2)
      end

      it 'ensures widget definitions are not considered equal across different custom types' do
        widgets_1 = custom_type_1.widget_definitions
        widgets_2 = custom_type_2.widget_definitions

        matching_widget_types = widgets_1.map(&:widget_type) & widgets_2.map(&:widget_type)
        expect(matching_widget_types).not_to be_empty

        matching_widget_types.each do |widget_type|
          widget_1 = widgets_1.find { |w| w.widget_type == widget_type }
          widget_2 = widgets_2.find { |w| w.widget_type == widget_type }

          expect(widget_1).not_to eq(widget_2)
          expect(widget_1.hash).not_to eq(widget_2.hash)
        end
      end
    end
  end

  describe '#widgets' do
    let_it_be(:resource_parent) { create(:group) }

    context 'when converted from system-defined type' do
      let(:custom_type) { create(:work_item_custom_type, :converted_from_issue) }

      it 'returns widgets with widget_class' do
        widgets = custom_type.widgets(resource_parent)

        expect(widgets).to all(satisfy { |w| w.widget_class.present? })
      end

      it 'filters out unlicensed widgets' do
        stub_licensed_features(issue_weights: false)

        widgets = custom_type.widgets(resource_parent)
        widget_types = widgets.map(&:widget_type)

        expect(widget_types).not_to include('weight')
      end

      it 'includes licensed widgets' do
        stub_licensed_features(issue_weights: true)

        widgets = custom_type.widgets(resource_parent)
        widget_types = widgets.map(&:widget_type)

        expect(widget_types).to include('weight')
      end
    end

    context 'when not converted (new custom type)' do
      let(:custom_type) { create(:work_item_custom_type) }

      it 'returns widgets from the default issue delegation source' do
        widgets = custom_type.widgets(resource_parent)

        expect(widgets).to be_present
        expect(widgets).to all(satisfy { |w| w.widget_class.present? })
      end
    end

    context 'with the agent_plan widget' do
      before do
        stub_licensed_features(ai_workflows: true)
      end

      shared_examples 'gating the agent_plan widget behind the feature flag' do
        it 'includes the agent_plan widget' do
          widget_types = custom_type.widgets(resource_parent).map(&:widget_type)

          expect(widget_types).to include('agent_plan')
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(workplan: false)
          end

          it 'excludes the agent_plan widget' do
            widget_types = custom_type.widgets(resource_parent).map(&:widget_type)

            expect(widget_types).not_to include('agent_plan')
          end
        end
      end

      context 'when converted from system-defined type' do
        let(:custom_type) { create(:work_item_custom_type, :converted_from_issue) }

        it_behaves_like 'gating the agent_plan widget behind the feature flag'
      end

      context 'when not converted (new custom type)' do
        let(:custom_type) { create(:work_item_custom_type) }

        it_behaves_like 'gating the agent_plan widget behind the feature flag'
      end
    end
  end

  describe '#custom_status_enabled_for?' do
    let_it_be(:test_namespace) { create(:group) }

    before do
      stub_licensed_features(work_item_status: true)
      allow_any_instance_of(WorkItems::TypeCustomLifecycle).to receive(:valid?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf -- needed to bypass HasType validation for custom type IDs
    end

    context 'when converted from system-defined type' do
      let(:custom_type) { create(:work_item_custom_type, :converted_from_issue, namespace: test_namespace) }

      context 'when TypeCustomLifecycle exists for converted_from_system_defined_type_identifier' do
        before do
          lifecycle = create(:work_item_custom_lifecycle, namespace: test_namespace)
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type.converted_from_system_defined_type_identifier,
            namespace: test_namespace,
            lifecycle: lifecycle)
        end

        it 'returns true' do
          expect(custom_type.custom_status_enabled_for?(test_namespace.id)).to be(true)
        end
      end

      context 'when TypeCustomLifecycle does not exist' do
        it 'returns false' do
          expect(custom_type.custom_status_enabled_for?(test_namespace.id)).to be(false)
        end
      end
    end

    context 'when not converted (new custom type)' do
      let(:custom_type) { create(:work_item_custom_type, namespace: test_namespace) }

      context 'when TypeCustomLifecycle exists for the custom type id' do
        before do
          lifecycle = create(:work_item_custom_lifecycle, namespace: test_namespace)
          create(:work_item_type_custom_lifecycle,
            work_item_type_id: custom_type.id,
            namespace: test_namespace,
            lifecycle: lifecycle)
        end

        it 'returns true' do
          expect(custom_type.custom_status_enabled_for?(test_namespace.id)).to be(true)
        end
      end

      context 'when TypeCustomLifecycle does not exist' do
        it 'returns false' do
          expect(custom_type.custom_status_enabled_for?(test_namespace.id)).to be(false)
        end
      end
    end

    context 'when namespace_id is nil' do
      let(:custom_type) { create(:work_item_custom_type, namespace: test_namespace) }

      it 'returns false' do
        expect(custom_type.custom_status_enabled_for?(nil)).to be(false)
      end
    end
  end

  describe '#supports_assignee?' do
    let_it_be(:resource_parent) { create(:project) }

    context 'when not converted (delegates to issue type)' do
      let(:custom_type) { create(:work_item_custom_type) }

      it 'delegates to the delegation source' do
        expect(custom_type.supports_assignee?(resource_parent)).to eq(
          custom_type.delegation_source.supports_assignee?(resource_parent)
        )
      end

      it 'returns true since issue type supports assignees' do
        expect(custom_type.supports_assignee?(resource_parent)).to be(true)
      end
    end

    context 'when converted from a system-defined type' do
      let(:custom_type) { create(:work_item_custom_type, :converted_from_issue) }

      it 'delegates to the delegation source' do
        expect(custom_type.supports_assignee?(resource_parent)).to eq(
          custom_type.delegation_source.supports_assignee?(resource_parent)
        )
      end
    end
  end

  describe '#supports_time_tracking?' do
    let_it_be(:resource_parent) { create(:project) }

    context 'when not converted (delegates to issue type)' do
      let(:custom_type) { create(:work_item_custom_type) }

      it 'delegates to the delegation source' do
        expect(custom_type.supports_time_tracking?(resource_parent)).to eq(
          custom_type.delegation_source.supports_time_tracking?(resource_parent)
        )
      end

      it 'returns true since issue type supports time tracking' do
        expect(custom_type.supports_time_tracking?(resource_parent)).to be(true)
      end
    end

    context 'when converted from a system-defined type' do
      let(:custom_type) { create(:work_item_custom_type, :converted_from_issue) }

      it 'delegates to the delegation source' do
        expect(custom_type.supports_time_tracking?(resource_parent)).to eq(
          custom_type.delegation_source.supports_time_tracking?(resource_parent)
        )
      end
    end
  end

  describe '.augment_with_sibling_custom_descendants' do
    let_it_be(:descendant_namespace) { create(:group) }

    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    context 'when resource_parent is nil' do
      it 'returns the system descendants unchanged' do
        system_descendants = [build(:work_item_system_defined_type, :task)]

        expect(described_class.augment_with_sibling_custom_descendants(system_descendants, nil))
          .to eq(system_descendants)
      end
    end

    context 'with non-converted custom types in the namespace' do
      let_it_be(:non_converted_custom_type) do
        create(:work_item_custom_type, namespace: descendant_namespace, name: 'Bug')
      end

      let_it_be(:converted_custom_type) do
        create(:work_item_custom_type, :converted_from_task, namespace: descendant_namespace, name: 'Sub-task')
      end

      let(:issue_system_type) { build(:work_item_system_defined_type, :issue) }
      let(:task_system_type) { build(:work_item_system_defined_type, :task) }

      it 'appends sibling non-converted custom types matching one of the system descendants' do
        # Pretend issue is the system descendant we are augmenting against; the bug custom
        # type delegates to issue and should be appended.
        result = described_class
          .augment_with_sibling_custom_descendants([issue_system_type], descendant_namespace)

        appended = result - [issue_system_type]
        expect(appended.map(&:id)).to include(non_converted_custom_type.id)
      end

      it 'does not append unrelated siblings whose delegation_source does not match' do
        # The bug custom type delegates to issue, not task, so when augmenting against task
        # it must not be added.
        result = described_class
          .augment_with_sibling_custom_descendants([task_system_type], descendant_namespace)

        appended = result - [task_system_type]
        expect(appended.map(&:id)).not_to include(non_converted_custom_type.id)
      end

      it 'does not append converted custom types even if their delegation_source matches' do
        # Converted types are already represented in the system descendants list returned by
        # the Provider (via replacement), so the augmentation must not add them again.
        result = described_class
          .augment_with_sibling_custom_descendants([issue_system_type], descendant_namespace)

        appended = result - [issue_system_type]
        expect(appended.map(&:id)).not_to include(converted_custom_type.id)
      end
    end
  end
end
