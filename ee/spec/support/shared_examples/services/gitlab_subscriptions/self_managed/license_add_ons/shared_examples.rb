# frozen_string_literal: true

# Requires the following pre-defined variable/subject:
#   `add_on_license`: Initialized add-on license class, example: `<class_name>.new(restrictions)`
#
# Requires the add-on name to be passed in as a String, example: "duo_pro"
RSpec.shared_examples "license add-on attributes" do |add_on_name:|
  let_it_be(:today, freeze: false) { Date.current }
  let(:start_date) { today }
  let(:end_date) { start_date + 1.year }
  let(:quantity) { 10 }
  let(:add_on_products) do
    {
      add_on_name => [
        {
          "quantity" => quantity,
          "started_on" => start_date.to_s,
          "expires_on" => end_date.to_s,
          "purchase_xid" => "C-0000001",
          "trial" => false
        }
      ]
    }
  end

  let(:restrictions) do
    { add_on_products: add_on_products }
  end

  it "sets the correct values" do
    expect(add_on_license).to have_attributes(
      quantity: 10,
      starts_at: start_date,
      expires_on: end_date,
      purchase_xid: "C-0000001",
      trial?: false
    )
  end

  context "without restrictions" do
    let(:restrictions) { nil }

    it "does not set any attributes" do
      expect(add_on_license).to have_attributes(
        quantity: 0,
        starts_at: nil,
        expires_on: nil,
        purchase_xid: nil,
        trial?: false
      )
    end
  end

  context "without the add-on info" do
    let(:add_on_products) do
      {
        "add_on" => [
          {
            "quantity" => quantity,
            "started_on" => start_date.to_s,
            "expires_on" => end_date.to_s,
            "purchase_xid" => "C-0000002",
            "trial" => false
          }
        ]
      }
    end

    it "does not set any attributes" do
      expect(add_on_license).to have_attributes(
        quantity: 0,
        starts_at: nil,
        expires_on: nil,
        purchase_xid: nil,
        trial?: false
      )
    end
  end

  context "with mixed hash key types" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            quantity: quantity,
            "started_on" => start_date.to_s,
            expires_on: end_date.to_s,
            "purchase_xid" => "C-0000003",
            trial: false
          }
        ]
      }
    end

    it "sets the correct values" do
      expect(add_on_license).to have_attributes(
        quantity: 10,
        starts_at: start_date,
        expires_on: end_date,
        purchase_xid: "C-0000003",
        trial?: false
      )
    end
  end

  context "without a quantity" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            "started_on" => start_date.to_s,
            "expires_on" => end_date.to_s,
            "purchase_xid" => "C-0000004",
            "trial" => false
          }
        ]
      }
    end

    it "sets the correct values" do
      expect(add_on_license).to have_attributes(
        quantity: 0,
        starts_at: start_date,
        expires_on: end_date,
        purchase_xid: "C-0000004",
        trial?: false
      )
    end
  end

  context "without a start date" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            "quantity" => quantity,
            "expires_on" => end_date.to_s,
            "purchase_xid" => "C-0000005",
            "trial" => false
          }
        ]
      }
    end

    it "does not set any attributes" do
      expect(add_on_license).to have_attributes(
        quantity: 0,
        starts_at: nil,
        expires_on: nil,
        purchase_xid: nil,
        trial?: false
      )
    end
  end

  context "without an end date" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            "quantity" => quantity,
            "started_on" => start_date.to_s,
            "purchase_xid" => "C-0000006",
            "trial" => false
          }
        ]
      }
    end

    it "does not set any attributes" do
      expect(add_on_license).to have_attributes(
        quantity: 0,
        starts_at: nil,
        expires_on: nil,
        purchase_xid: nil,
        trial?: false
      )
    end
  end

  context "without a purchase_xid" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            "quantity" => quantity,
            "started_on" => start_date.to_s,
            "expires_on" => end_date.to_s,
            "trial" => false
          }
        ]
      }
    end

    it "does not set purchase_xid" do
      expect(add_on_license).to have_attributes(
        quantity: 10,
        starts_at: start_date,
        expires_on: end_date,
        purchase_xid: nil,
        trial?: false
      )
    end
  end

  context "without trial" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            "quantity" => quantity,
            "started_on" => start_date.to_s,
            "expires_on" => end_date.to_s,
            "purchase_xid" => "C-0000007"
          }
        ]
      }
    end

    it "does not set any attributes" do
      expect(add_on_license).to have_attributes(
        quantity: 10,
        starts_at: start_date,
        expires_on: end_date,
        purchase_xid: "C-0000007",
        trial?: false
      )
    end
  end

  context "with trial set to true" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            "quantity" => quantity,
            "started_on" => start_date.to_s,
            "expires_on" => end_date.to_s,
            "purchase_xid" => "C-0000008",
            "trial" => true
          }
        ]
      }
    end

    it "sets trial to true" do
      expect(add_on_license).to have_attributes(
        quantity: 10,
        starts_at: start_date,
        expires_on: end_date,
        purchase_xid: "C-0000008",
        trial?: true
      )
    end
  end

  context "with an invalid key" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            "quantity" => quantity,
            "started_on" => start_date.to_s,
            "expires_on" => end_date.to_s,
            "purchase_xid" => "C-0000004",
            "trial" => false,
            "invalid_key" => 'invalid'
          }
        ]
      }
    end

    it "sets the correct values" do
      expect(add_on_license).to have_attributes(
        quantity: 10
      )
    end
  end

  context "with an expired and an active purchase" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            "quantity" => quantity,
            "started_on" => (start_date - 1.month).to_s,
            "expires_on" => start_date.to_s,
            "purchase_xid" => "C-0000009",
            "trial" => false
          },
          {
            "quantity" => quantity * 2,
            "started_on" => start_date.to_s,
            "expires_on" => end_date.to_s,
            "purchase_xid" => "C-00000010",
            "trial" => false
          }
        ]
      }
    end

    it "sets the correct values" do
      expect(add_on_license).to have_attributes(
        quantity: 20,
        starts_at: start_date,
        expires_on: end_date,
        purchase_xid: "C-00000010",
        trial?: false
      )
    end
  end

  context "with multiple active purchases" do
    let(:add_on_products) do
      past_start_date = start_date - 1.month
      new_end_date = past_start_date + 1.year

      {
        add_on_name => [
          {
            "quantity" => quantity * 2,
            "started_on" => past_start_date.to_s,
            "expires_on" => new_end_date.to_s,
            "purchase_xid" => "C-0000011",
            "trial" => false
          },
          {
            "quantity" => quantity,
            "started_on" => start_date.to_s,
            "expires_on" => new_end_date.to_s,
            "purchase_xid" => "C-0000012",
            "trial" => false
          }
        ]
      }
    end

    it "sets the consolidated values" do
      expect(add_on_license).to have_attributes(
        quantity: 30,
        starts_at: start_date - 1.month,
        expires_on: start_date - 1.month + 1.year,
        purchase_xid: "C-0000011",
        trial?: false
      )
    end
  end

  context "with an active and a future dated purchase" do
    let(:add_on_products) do
      {
        add_on_name => [
          {
            "quantity" => quantity,
            "started_on" => start_date.to_s,
            "expires_on" => end_date.to_s,
            "purchase_xid" => "C-0000013",
            "trial" => false
          },
          {
            "quantity" => quantity * 2,
            "started_on" => (start_date + 1.month).to_s,
            "expires_on" => end_date.to_s,
            "purchase_xid" => "C-0000014",
            "trial" => false
          }
        ]
      }
    end

    it "sets the consolidated quantity as well as the minimum start date and maximum end date" do
      expect(add_on_license).to have_attributes(
        quantity: 10,
        starts_at: start_date,
        expires_on: end_date,
        purchase_xid: "C-0000013",
        trial?: false
      )
    end
  end
end
