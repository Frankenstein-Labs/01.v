# frozen_string_literal: true

RSpec.shared_examples 'creates a legacy destination' do |model_class, attributes_proc|
  let(:attributes_map) { instance_exec(&attributes_proc) }

  def get_secret_token(model, category)
    case category
    when :http then model.verification_token
    when :aws then model.secret_access_key
    when :gcp then model.private_key
    end
  end

  it 'creates a legacy destination with correct attributes' do
    expect { mutate }.to change { model_class.count }.by(1)

    source_model = model_class.last
    expect(source_model).to be_present

    stream_model = source_model
    legacy_model = source_model.legacy_destination

    expect(legacy_model).to be_present

    expect(stream_model.config).to include(attributes_map[:streaming])
    attributes_map[:legacy].each do |attr, value|
      expect(legacy_model.public_send(attr)).to eq(value)
    end
    expect(get_secret_token(legacy_model, stream_model.category.to_sym)).to eq(source_model.secret_token)
    expect(legacy_model.namespace_id).to eq(stream_model.group_id) if stream_model.respond_to?(:group_id)

    if stream_model.http?
      expect(legacy_model.event_type_filters.count).to eq(stream_model.event_type_filters.count)
      expect(legacy_model.namespace_filter&.namespace).to eq(stream_model.namespace_filters.first&.namespace)
    end

    expect(stream_model.name).to eq(legacy_model.name)
    expect(stream_model.legacy_destination_ref).to eq(legacy_model.id)
    expect(legacy_model.stream_destination_id).to eq(stream_model.id)
  end
end

RSpec.shared_examples 'updates a legacy destination' do |destination, attributes|
  def get_secret_token(model, category)
    case category
    when :http then model.verification_token
    when :aws then model.secret_access_key
    when :gcp then model.private_key
    end
  end

  context 'when feature flag is enabled' do
    let(:attributes_map) { instance_exec(&attributes) }

    let(:stream_destination) { send(destination) }
    let(:paired_legacy_destination) { send(:legacy_destination) }

    before do
      stream_destination.update!(legacy_destination_ref: paired_legacy_destination.id)
      paired_legacy_destination.update!(stream_destination_id: stream_destination.id)
    end

    it 'updates the legacy destination with correct attributes' do
      mutate

      stream_destination.reload
      paired_legacy_destination.reload

      expect(stream_destination.legacy_destination_ref).to eq(legacy_destination.id)
      expect(paired_legacy_destination.stream_destination_id).to eq(stream_destination.id)
      expect(get_secret_token(paired_legacy_destination,
        stream_destination.category.to_sym)).to eq(stream_destination.secret_token)

      attributes_map[:streaming].each do |key, value|
        if key == "name"
          expect(stream_destination.name).to eq(value)
        else
          expect(stream_destination.config[key]).to eq(value)
        end

        attributes_map[:legacy].each do |key, value|
          expect(paired_legacy_destination[key]).to eq(value)
        end
      end
    end
  end
end
