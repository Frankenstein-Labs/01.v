# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attribute, feature_category: :security_asset_inventories do
  let_it_be(:parent) { create(:group) }

  describe 'associations' do
    it { is_expected.to belong_to(:security_category).required }
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:editable_state) }
    it { is_expected.to validate_presence_of(:color) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }

    context 'when validating uniqueness of name scoped to category, ignoring soft-deleted rows' do
      let_it_be(:security_category) { create(:security_category, namespace: parent, name: "validation test") }

      it 'is invalid when an active attribute with the same name exists in the same category', :aggregate_failures do
        create(:security_attribute, namespace: parent, security_category: security_category, name: 'Duplicate')

        duplicate = build(:security_attribute, namespace: parent, security_category: security_category,
          name: 'Duplicate')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end

      it 'is valid when the existing attribute with the same name is soft-deleted' do
        create(:security_attribute, :soft_deleted, namespace: parent, security_category: security_category,
          name: 'Reusable')

        reused = build(:security_attribute, namespace: parent, security_category: security_category, name: 'Reusable')
        expect(reused).to be_valid
      end
    end
  end

  describe '#before_validation' do
    it 'strips leading and trailing whitespace from name' do
      attribute = described_class.new(name: '  Test Label  ')
      attribute.valid?
      expect(attribute.name).to eq('Test Label')
    end

    it 'strips leading and trailing whitespace from description' do
      attribute = described_class.new(description: '   Test description   ')
      attribute.valid?
      expect(attribute.description).to eq('Test description')
    end
  end

  describe 'scopes' do
    let_it_be(:category) { create(:security_category, namespace: parent, name: 'Category') }
    let_it_be(:active_attribute) do
      create(:security_attribute, security_category: category, namespace: parent, name: 'Active')
    end

    let_it_be(:deleted_attribute) do
      create(:security_attribute, security_category: category, namespace: parent, name: 'Deleted',
        deleted_at: Time.current)
    end

    describe '.not_deleted' do
      it 'returns only attributes without deleted_at' do
        expect(described_class.not_deleted).to contain_exactly(active_attribute)
      end
    end

    describe '.deleted' do
      it 'returns only attributes with deleted_at' do
        expect(described_class.deleted).to contain_exactly(deleted_attribute)
      end
    end

    describe '.by_category_template_type' do
      let_it_be_with_reload(:business_impact_category) do
        create(:security_category, namespace: parent, name: 'Business Impact', template_type: :business_impact)
      end

      let_it_be(:no_template_category) { create(:security_category, namespace: parent, name: 'No Template') }

      let_it_be_with_reload(:business_impact_attr) do
        create(:security_attribute, security_category: business_impact_category, namespace: parent,
          name: 'Mission Critical')
      end

      let_it_be(:no_template_attr) do
        create(:security_attribute, security_category: no_template_category, namespace: parent,
          name: 'No Template Attr')
      end

      let(:template_type) { :business_impact }

      shared_examples 'returns empty' do
        it 'returns empty' do
          expect(attributes_by_category_template_type).to be_empty
        end
      end

      subject(:attributes_by_category_template_type) do
        described_class.by_category_template_type(template_type)
      end

      context 'when category matches the template type' do
        it 'returns attributes whose category has the given template type' do
          expect(attributes_by_category_template_type).to contain_exactly(business_impact_attr)
        end

        it 'excludes attributes whose category has no template type' do
          expect(attributes_by_category_template_type).not_to include(no_template_attr)
        end
      end

      context 'when no category matches the template type' do
        let(:template_type) { :business_unit }

        it_behaves_like 'returns empty'
      end

      context 'when template_type is nil' do
        let(:template_type) { nil }

        it_behaves_like 'returns empty'
      end

      context 'when template_type is blank' do
        let(:template_type) { '' }

        it_behaves_like 'returns empty'
      end

      context 'when attribute is soft deleted' do
        before do
          business_impact_attr.update!(deleted_at: Time.current)
        end

        it_behaves_like 'returns empty'
      end

      context 'when category has been soft deleted' do
        before do
          business_impact_category.update!(deleted_at: Time.current)
        end

        it_behaves_like 'returns empty'
      end

      context 'with multiple attributes in the matching category' do
        let_it_be_with_reload(:business_impact_attr2) do
          create(:security_attribute, security_category: business_impact_category, namespace: parent,
            name: 'BI Attr 2')
        end

        it 'returns all attributes from categories with the given template type' do
          expect(attributes_by_category_template_type).to contain_exactly(business_impact_attr, business_impact_attr2)
        end
      end
    end

    describe '.not_deleted_with_not_deleted_categories' do
      let_it_be(:deleted_category) do
        create(:security_category, namespace: parent, name: 'Deleted Category', deleted_at: Time.current)
      end

      let_it_be(:attr_in_deleted_category) do
        create(:security_attribute, security_category: deleted_category, namespace: parent,
          name: 'Attr in Deleted Category')
      end

      it 'includes active attributes with active categories' do
        expect(described_class.not_deleted_with_not_deleted_categories).to include(active_attribute)
      end

      it 'excludes soft-deleted attributes' do
        expect(described_class.not_deleted_with_not_deleted_categories).not_to include(deleted_attribute)
      end

      it 'excludes attributes whose category is soft-deleted' do
        expect(described_class.not_deleted_with_not_deleted_categories).not_to include(attr_in_deleted_category)
      end
    end

    describe '.by_category' do
      let_it_be(:category1) { create(:security_category, namespace: parent, name: 'Category 1') }
      let_it_be(:category2) { create(:security_category, namespace: parent, name: 'Category 2') }
      let_it_be(:attribute1) do
        create(:security_attribute, security_category: category1, namespace: parent, name: 'Attr 1')
      end

      let_it_be(:attribute2) do
        create(:security_attribute, security_category: category2, namespace: parent, name: 'Attr 2')
      end

      it 'returns only attributes from the specified category' do
        result = described_class.by_category(category1)

        expect(result).to include(attribute1)
        expect(result).not_to include(attribute2)
        expect(result.count).to eq(1)
      end
    end
  end

  describe '#destroy' do
    let(:category) { create(:security_category, namespace: parent, name: 'Category') }
    let!(:attribute) { create(:security_attribute, security_category: category, namespace: parent, name: 'Test') }

    it 'soft deletes the attribute by setting deleted_at' do
      expect { attribute.destroy! }.not_to change { described_class.unscoped.count }

      expect(attribute.reload.deleted_at).to be_present
      expect(attribute.deleted?).to be true
    end

    it 'removes the attribute from not_deleted scope' do
      attribute.destroy!

      expect(described_class.not_deleted.where(id: attribute.id)).to be_empty
      expect(described_class.unscoped.where(id: attribute.id)).to exist
    end
  end

  describe '.really_destroy_all!' do
    let(:category) { create(:security_category, namespace: parent, name: 'Category') }

    it 'permanently deletes multiple attributes from database' do
      attr1 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test1',
        deleted_at: Time.current)
      attr2 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test2',
        deleted_at: Time.current)
      attr3 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test3',
        deleted_at: Time.current)

      expect { described_class.really_destroy_all!([attr1.id, attr2.id, attr3.id]) }
        .to change { described_class.unscoped.count }.by(-3)

      expect(described_class.unscoped.where(id: [attr1.id, attr2.id, attr3.id])).to be_empty
    end

    it 'returns 0 when ids is nil' do
      expect(described_class.really_destroy_all!(nil)).to eq(0)
    end

    it 'returns 0 when ids is empty array' do
      expect(described_class.really_destroy_all!([])).to eq(0)
    end

    it 'only deletes specified attributes' do
      attr1 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test1',
        deleted_at: Time.current)
      attr2 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test2',
        deleted_at: Time.current)
      attr3 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test3',
        deleted_at: Time.current)

      expect { described_class.really_destroy_all!([attr1.id]) }
        .to change { described_class.unscoped.count }.by(-1)

      expect(described_class.unscoped.where(id: attr1.id)).to be_empty
      expect(described_class.unscoped.where(id: [attr2.id, attr3.id])).to exist
    end
  end

  describe '#deleted?' do
    let(:category) { create(:security_category, namespace: parent, name: 'Category') }

    it 'returns true when deleted_at is present' do
      attribute = create(:security_attribute, security_category: category, namespace: parent, deleted_at: Time.current)
      expect(attribute.deleted?).to be true
    end

    it 'returns false when deleted_at is nil' do
      attribute = create(:security_attribute, security_category: category, namespace: parent)
      expect(attribute.deleted?).to be false
    end
  end

  describe '#editable?' do
    it 'returns true when editable_state is not locked' do
      attribute = build(:security_attribute, editable_state: 'editable')
      expect(attribute.editable?).to be true
    end

    it 'returns false when editable_state is locked' do
      attribute = build(:security_attribute, editable_state: 'locked')
      expect(attribute.editable?).to be false
    end
  end

  context 'with loose foreign key on security_attribute.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:security_category) { create(:security_category, namespace: parent, name: "lfk test") }
      let_it_be(:model) { create(:security_attribute, namespace: parent, security_category: security_category) }
    end
  end
end
