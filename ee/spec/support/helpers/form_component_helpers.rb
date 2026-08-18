# frozen_string_literal: true

module FormComponentHelpers
  def parsed_component_data
    element = component.find(view_model_selector)
    ::Gitlab::Json.safe_parse(element['data-view-model'])
  end

  def expect_form_data_attribute(data_attributes)
    data = parsed_component_data

    data_attributes.each do |attribute, value|
      expect(data[attribute]).to eq(value)
    end
  end
end
