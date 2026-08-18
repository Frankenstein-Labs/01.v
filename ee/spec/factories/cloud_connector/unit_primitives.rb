# frozen_string_literal: true

FactoryBot.define do
  factory :cloud_connector_unit_primitive, class: 'Gitlab::CloudConnector::DataModel::UnitPrimitive' do
    initialize_with { new(**attributes) }

    name { 'unit_primitive_name' }
    cut_off_date { Time.current - 1.day }
    add_ons { [association(:cloud_connector_add_on)] }
    backend_services { [association(:cloud_connector_backend_service)] }
  end

  trait :no_cut_off_date do
    cut_off_date { nil }
  end

  trait :future_cut_off_date do
    cut_off_date { Time.current + 1.day }
  end

  trait :complete_code do
    name { 'complete_code' }
    add_ons { [association(:cloud_connector_add_on, name: 'duo_pro')] }
  end
end
