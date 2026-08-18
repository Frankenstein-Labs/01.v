# frozen_string_literal: true

FactoryBot.define do
  factory :geo_node_organization_link, class: "Geo::GeoNodeOrganizationLink" do
    geo_node
    organization
  end
end
