# frozen_string_literal: true

RSpec.describe RSpec::ExtraMatchers do
  it "has a version number" do
    expect(RSpec::ExtraMatchers::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
