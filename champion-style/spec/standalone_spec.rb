require 'rspec'

puts "Loading standalone_spec.rb"
puts "Methods on Object: #{Object.methods.include?(:describe)}"

RSpec.describe 'Standalone Test' do
  it 'runs a simple test' do
    expect(true).to eq(true)
  end
end