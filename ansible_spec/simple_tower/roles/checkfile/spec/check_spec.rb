require 'spec_helper'

# describe file('/etc/passwd') do
# describe file( {myfname} ) do

describe file( property["myfname"] ) do
  it { should be_file }
  #it { should contain property["fcont"] }
end

