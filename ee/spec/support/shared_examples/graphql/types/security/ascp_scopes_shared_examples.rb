# frozen_string_literal: true

RSpec.shared_examples 'an ASCP type with field scopes' do |fields:, scopes: %i[api read_api ai_workflows]|
  describe 'field scopes' do
    fields.each do |field_name|
      camel_field = field_name.camelize(:lower)

      it "includes the correct scopes for #{field_name}" do
        expect(described_class.fields[camel_field].instance_variable_get(:@scopes))
          .to include(*scopes), "expected field #{camel_field} to include scopes #{scopes}"
      end
    end
  end

  describe '.authorization_scopes' do
    it 'includes the expected scopes' do
      expect(described_class.authorization_scopes).to include(*scopes)
    end
  end
end

RSpec.shared_examples 'an ASCP mutation with scopes' do |field_name:, scopes: %i[api ai_workflows]|
  describe 'field scopes' do
    it "includes the correct scopes for the #{field_name} field" do
      expect(described_class.fields[field_name].instance_variable_get(:@scopes))
        .to include(*scopes)
    end
  end

  describe '.authorization_scopes' do
    it 'includes the expected scopes' do
      expect(described_class.authorization_scopes).to match_array(scopes)
    end
  end
end
