# frozen_string_literal: true

RSpec.shared_examples 'a work item custom field value' do |factory:|
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:work_item) }
    it { is_expected.to belong_to(:custom_field) }
  end

  describe 'validations' do
    describe 'namespace' do
      subject { build(factory, work_item: nil) }

      it { is_expected.to validate_presence_of(:namespace) }
    end

    it { is_expected.to validate_presence_of(:work_item) }
    it { is_expected.to validate_presence_of(:custom_field) }

    describe '#copy_namespace_from_work_item' do
      let(:work_item) { create(:work_item) }

      it 'copies namespace_id from the associated work item' do
        expect do
          subject.work_item = work_item
          subject.valid?
        end.to change { subject.namespace_id }.from(nil).to(work_item.namespace_id)
      end
    end
  end

  describe '.for_field_and_work_item' do
    let(:custom_field_1) { create(:custom_field) }
    let(:custom_field_2) { create(:custom_field) }
    let(:work_item_1) { create(:work_item) }
    let(:work_item_2) { create(:work_item) }

    it 'returns records matching the custom_field_id and work_item_id' do
      matching_value = create(factory, custom_field: custom_field_1, work_item: work_item_1)

      create(factory, custom_field: custom_field_1, work_item: work_item_2)
      create(factory, custom_field: custom_field_2, work_item: work_item_1)
      create(factory, custom_field: custom_field_2, work_item: work_item_2)

      expect(
        described_class.for_field_and_work_item(custom_field_1, work_item_1)
      ).to contain_exactly(matching_value)
    end
  end

  describe '.for_work_item' do
    let(:work_item1) { create(:work_item) }
    let(:work_item2) { create(:work_item) }
    let(:custom_field) { create(:custom_field) }

    let!(:custom_field_value1) { create(factory, work_item: work_item1, custom_field: custom_field) }
    let!(:custom_field_value2) { create(factory, work_item: work_item2, custom_field: custom_field) }

    it 'returns only custom field values for the specified work item' do
      result = described_class.for_work_item(work_item1.id)

      expect(result).to include(custom_field_value1)
      expect(result).not_to include(custom_field_value2)
    end

    it 'returns empty relation when work item has no custom field values' do
      new_work_item = create(:work_item)

      result = described_class.for_work_item(new_work_item.id)

      expect(result).to be_empty
    end
  end
end
