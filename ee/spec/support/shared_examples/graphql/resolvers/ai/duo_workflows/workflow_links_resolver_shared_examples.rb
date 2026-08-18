# frozen_string_literal: true

RSpec.shared_examples 'a workflow links resolver' do |type:, association:|
  specify { expect(described_class.type).to eq(type.connection_type) }
  specify { expect(described_class.arguments.keys).to contain_exactly('linkType') }
  specify { expect(described_class.links_association).to eq(association) }
end
