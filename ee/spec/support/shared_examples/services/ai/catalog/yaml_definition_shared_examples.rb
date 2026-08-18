# frozen_string_literal: true

RSpec.shared_examples 'validates yaml definition syntax' do |item_type = 'Flow'|
  context 'when the provided YAML is not structured correctly' do
    before do
      params[:definition] = '"invalid: yaml data'
    end

    it_behaves_like 'an error response', ["#{item_type} definition does not have a valid YAML syntax"]
  end

  context 'when the provided YAML is a string scalar' do
    before do
      params[:definition] = 'just a string'
    end

    it_behaves_like 'an error response', ["#{item_type} definition does not have a valid YAML syntax"]
  end

  context 'when the provided YAML contains a disallowed class' do
    before do
      params[:definition] = "--- !ruby/object:Gem::Requirement {}"
    end

    it_behaves_like 'an error response', ["#{item_type} definition does not have a valid YAML syntax"]
  end

  context 'when the provided YAML has an alias' do
    before do
      params[:definition] = "*foo"
    end

    it_behaves_like 'an error response', ["#{item_type} definition does not have a valid YAML syntax"]
  end

  context 'when the provided YAML is an array' do
    before do
      params[:definition] = "- item1\n- item2"
    end

    it_behaves_like 'an error response', ["#{item_type} definition does not have a valid YAML syntax"]
  end
end

RSpec.shared_examples 'handles missing yaml definition' do
  context 'when definition is not provided' do
    let(:params) { super().except(:definition) }

    it 'does not update the definition' do
      existing_definition = latest_version.definition

      execute_service

      expect(latest_version.reload.definition).to eq(existing_definition)
    end
  end
end

RSpec.shared_examples 'yaml definition create service behavior' do |item_type = 'Flow'|
  it_behaves_like 'validates yaml definition syntax', item_type

  context 'when definition is provided and valid' do
    it 'creates item version with parsed YAML definition' do
      expect { execute_service }.to change { Ai::Catalog::ItemVersion.count }.by(1)

      item = Ai::Catalog::Item.last
      expected_definition = YAML.safe_load(definition).merge('yaml_definition' => definition)
      expect(item.latest_version.definition).to eq(expected_definition)
    end
  end
end

RSpec.shared_examples 'yaml definition update service behavior' do |item_type = 'Flow'|
  it_behaves_like 'validates yaml definition syntax', item_type
  it_behaves_like 'handles missing yaml definition'

  context 'when definition is provided and valid' do
    it 'updates the definition correctly' do
      expected_definition = YAML.safe_load(definition).merge('yaml_definition' => definition)

      expect { execute_service }
        .to change { latest_version.reload.definition }
        .to(expected_definition)
    end
  end
end
