# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Category, feature_category: :security_asset_inventories do
  let_it_be(:root_level_group) { create(:group) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:editable_state) }
    it { is_expected.to validate_inclusion_of(:multiple_selection).in_array([true, false]) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }

    context 'when validating uniqueness of name scoped to namespace, ignoring soft-deleted rows' do
      it 'is invalid when an active category with the same name exists in the same namespace', :aggregate_failures do
        create(:security_category, namespace: root_level_group, name: 'Duplicate')

        duplicate = build(:security_category, namespace: root_level_group, name: 'Duplicate')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end

      it 'is valid when the existing category with the same name is soft-deleted' do
        create(:security_category, :soft_deleted, namespace: root_level_group, name: 'Reusable')

        reused = build(:security_category, namespace: root_level_group, name: 'Reusable')

        expect(reused).to be_valid
      end
    end

    describe '#valid_namespace' do
      let_it_be(:subgroup) { create(:group, parent: root_level_group) }
      let_it_be(:project_namespace) { create(:project_namespace) }

      it 'is valid for root group namespace' do
        expect(build(:security_category, namespace: root_level_group)).to be_valid
      end

      it 'is invalid for non-root namespaces' do
        [subgroup, project_namespace].each do |invalid_namespace|
          category = build(:security_category, namespace: invalid_namespace)

          expect(category).not_to be_valid
          expect(category.errors[:namespace]).to include('must be a root group.')
        end
      end
    end

    describe '#strip_whitespaces' do
      it 'strips whitespace from name and description' do
        category = build(:security_category, namespace: root_level_group, name: "  Category with whitespace  ",
          description: "  Description with whitespace  ")

        category.valid?

        expect(category.name).to eq("Category with whitespace")
        expect(category.description).to eq("Description with whitespace")
      end
    end

    describe '#attributes_limit' do
      let(:category) { create(:security_category, namespace: root_level_group) }

      before do
        stub_const('Security::Category::MAX_ATTRIBUTES', 3)
      end

      it 'allows up to MAX_ATTRIBUTES security attributes' do
        create_list(:security_attribute, Security::Category::MAX_ATTRIBUTES - 1, security_category: category,
          namespace: root_level_group)

        category.security_attributes <<
          build(:security_attribute, security_category: category, namespace: root_level_group, name: "MAX_ATTRIBUTES")
        expect(category).to be_valid
      end

      it 'prevents having more than MAX_ATTRIBUTES security attributes' do
        create_list(:security_attribute, Security::Category::MAX_ATTRIBUTES, security_category: category,
          namespace: root_level_group)

        category.security_attributes <<
          build(:security_attribute, security_category: category, namespace: root_level_group, name: "MAX_ATTRIBUTES+1")

        expect(category).not_to be_valid
        expect(category.errors[:security_attributes])
          .to include("cannot have more than #{Security::Category::MAX_ATTRIBUTES} attributes per category")
      end

      it 'only counts active attributes towards the limit' do
        create_list(:security_attribute, Security::Category::MAX_ATTRIBUTES, security_category: category,
          namespace: root_level_group)

        # Soft delete one attribute
        category.security_attributes.first.update!(deleted_at: Time.current)

        # Should now be able to add one more
        category.security_attributes <<
          build(:security_attribute, security_category: category, namespace: root_level_group,
            name: "added after deletion")

        expect(category).to be_valid
      end
    end
  end

  describe 'scopes' do
    let_it_be(:active_category) { create(:security_category, namespace: root_level_group, name: 'Active') }
    let_it_be(:deleted_category) do
      create(:security_category, namespace: root_level_group, name: 'Deleted', deleted_at: Time.current)
    end

    describe '.not_deleted' do
      it 'returns only categories without deleted_at' do
        expect(described_class.not_deleted).to contain_exactly(active_category)
      end
    end

    describe '.deleted' do
      it 'returns only categories with deleted_at' do
        expect(described_class.deleted).to contain_exactly(deleted_category)
      end
    end

    describe '.by_namespace' do
      let(:another_root_level_group) { create(:group) }
      let(:category) { create(:security_category, namespace: root_level_group) }
      let(:another_category) { create(:security_category, namespace: another_root_level_group) }

      it 'returns the correct categories' do
        expect(described_class.by_namespace(root_level_group)).to match_array([active_category, category])
      end
    end

    describe '.by_namespace_and_template_type' do
      let(:category1) do
        create(:security_category, namespace: root_level_group, template_type: :business_unit, name: "1")
      end

      let(:category2) do
        create(:security_category, namespace: root_level_group, template_type: :application, name: "2")
      end

      it 'returns the correct category' do
        expect(described_class.by_namespace_and_template_type(root_level_group, :application)).to match_array(category2)
      end
    end

    describe '.preload_not_deleted_attributes' do
      let_it_be(:category) { create(:security_category, namespace: root_level_group, name: 'With attributes') }
      let_it_be(:active_attribute) do
        create(:security_attribute, security_category: category, namespace: root_level_group, name: 'Active attr')
      end

      let_it_be(:deleted_attribute) do
        create(:security_attribute, security_category: category, namespace: root_level_group, name: 'Deleted attr',
          deleted_at: Time.current)
      end

      subject(:preloaded) { described_class.by_namespace(root_level_group).preload_not_deleted_attributes.to_a }

      it 'preloads only non-deleted attributes', :aggregate_failures do
        with_attributes = preloaded.find { |c| c.id == category.id }

        expect(with_attributes.association(:not_deleted_security_attributes)).to be_loaded
        expect(with_attributes.not_deleted_security_attributes).to contain_exactly(active_attribute)
      end
    end
  end

  describe '#destroy' do
    let(:category) { create(:security_category, namespace: root_level_group, name: 'Test') }
    let!(:attribute1) do
      create(:security_attribute, security_category: category, namespace: root_level_group, name: 'Attr1')
    end

    let!(:attribute2) do
      create(:security_attribute, security_category: category, namespace: root_level_group, name: 'Attr2')
    end

    it 'soft deletes the category by setting deleted_at' do
      expect { category.destroy! }.not_to change { described_class.unscoped.count }

      expect(category.reload.deleted_at).to be_present
      expect(category.deleted?).to be true
    end

    it 'soft deletes all active attributes when category is soft deleted' do
      category.destroy!

      expect(attribute1.reload.deleted_at).to be_present
      expect(attribute2.reload.deleted_at).to be_present
    end

    it 'removes the category from not_deleted scope' do
      category.destroy!

      expect(described_class.not_deleted.where(id: category.id)).to be_empty
      expect(described_class.unscoped.where(id: category.id)).to exist
    end
  end

  describe '.really_destroy_by_id!' do
    it 'permanently deletes the category from database by id' do
      category = create(:security_category, namespace: root_level_group, name: 'Test', deleted_at: Time.current)

      expect { described_class.really_destroy_by_id!(category.id) }
        .to change { described_class.unscoped.count }.by(-1)

      expect(described_class.unscoped.where(id: category.id)).to be_empty
    end

    it 'returns 0 when category_id is nil' do
      expect(described_class.really_destroy_by_id!(nil)).to eq(0)
    end

    it 'returns 0 when category_id does not exist' do
      expect(described_class.really_destroy_by_id!(non_existing_record_id)).to eq(0)
    end
  end

  describe '#deleted?' do
    it 'returns true when deleted_at is present' do
      category = create(:security_category, namespace: root_level_group, deleted_at: Time.current)
      expect(category.deleted?).to be true
    end

    it 'returns false when deleted_at is nil' do
      category = create(:security_category, namespace: root_level_group)
      expect(category.deleted?).to be false
    end
  end

  context 'with loose foreign key on security_category.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:security_category, namespace: parent) }
    end
  end
end
