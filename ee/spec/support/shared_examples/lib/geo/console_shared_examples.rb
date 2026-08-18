# frozen_string_literal: true

# Requires let variables:
# - current_node
# - choice
# - output_stream
RSpec.shared_examples_for "a Geo console choice" do
  it "outputs the header" do
    site_label = if current_node.primary?
                   "Geo Primary Site"
                 elsif current_node.org_migration_target?
                   "Org Migration Target Cell"
                 else
                   "Geo Secondary Site"
                 end

    header = <<~HEADER
      --------------------------------------------------------------------------------
      Geo Developer Console | #{site_label} | #{current_node.name}
      #{choice.name}
      --------------------------------------------------------------------------------
    HEADER

    choice.open

    expect(output_stream.string).to include(header)
  end
end

# Requires let variables:
# - current_node
# - action
# - output_stream
RSpec.shared_examples_for "a Geo console action" do
  it_behaves_like "a Geo console choice" do
    let(:choice) { action }
  end
end

# Requires let variables:
# - current_node
# - menu
# - input_stream
# - output_stream
RSpec.shared_examples_for "a Geo console multiple choice menu with a current_node" do
  before do
    # Opening any Choice other than Geo::Console::Exit will always lead to another `gets` called on
    # the input stream. But we want a unit test of a menu to stop execution just before moving on to
    # the next Choice.
    allow(menu).to receive(:open_choice)
  end

  it_behaves_like "a Geo console choice" do
    let(:choice) { menu }
  end

  it "outputs each choice" do
    choice_names = menu.send(:total_choices).map(&:name)

    menu.open

    choice_names.each do |name|
      expect(output_stream.string).to include(name)
    end
  end

  it "has at least one choice" do
    menu.open

    expect(output_stream.string).to include("1) ")
  end

  it "prompts for input" do
    menu.open

    prompt = <<~PROMPT.chomp
      What would you like to do?
      Enter a number:
    PROMPT

    feedback = <<~FEEDBACK
      You entered: #{input_stream.string.chomp}
      You chose: #{menu.send(:total_choices).first.name}
    FEEDBACK

    expect(output_stream.string).to include(prompt)
    expect(output_stream.string).to include(feedback)
  end
end

# Requires let variables:
# - menu
# - input_stream
# - output_stream
RSpec.shared_examples_for "a Geo console multiple choice menu" do
  describe "#open" do
    before do
      # Finish, instead of opening the next Choice.
      allow(menu).to receive(:open_choice)
    end

    context "when Geo is enabled" do
      context "when the current machine name matches a Geo node" do
        before do
          stub_current_geo_node(current_node)
        end

        context "when on a primary Geo node" do
          let_it_be(:current_node, freeze: true) { create(:geo_node, primary: true, name: "New York") }

          it_behaves_like "a Geo console multiple choice menu with a current_node"
        end

        context "when on a secondary Geo node" do
          let_it_be(:current_node, freeze: true) { create(:geo_node, primary: false, name: "Tokyo") }

          it_behaves_like "a Geo console multiple choice menu with a current_node"
        end

        context "when on an org migration target Geo node" do
          let_it_be(:current_node, freeze: true) { create(:geo_node, primary: false, name: "Berlin") }

          before do
            stub_org_migration_target_cell(current_node)
          end

          it_behaves_like "a Geo console multiple choice menu with a current_node"
        end
      end

      context "when the current machine name does not match a Geo node" do
        it "raises an error" do
          stub_geo_nodes_exist_but_none_match_current_node

          expect { menu.open }.to raise_error("Geo enabled but I don't know what site I am a part of")
        end
      end
    end

    context 'when Geo is not enabled' do
      it "raises an error" do
        expect { menu.open }.to raise_error("Geo not enabled")
      end
    end
  end
end
