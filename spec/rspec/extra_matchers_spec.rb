# frozen_string_literal: true

RSpec.describe RSpec::ExtraMatchers do
  it "has a version number" do
    expect(RSpec::ExtraMatchers::VERSION).not_to be nil
  end
end
