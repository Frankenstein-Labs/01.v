# frozen_string_literal: true

FactoryBot.define do
  factory :geo_event, class: 'Geo::Event' do
    replicable_name { 'package_file' }
    event_name { 'created' }

    trait :package_file do
      payload do
        {
          "model_record_id" => create(:package_file, :pom).id,
          "correlation_id" => Labkit::Correlation::CorrelationId.current_or_new_id
        }
      end
    end
  end
end
