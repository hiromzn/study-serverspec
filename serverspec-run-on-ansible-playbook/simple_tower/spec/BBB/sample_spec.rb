require 'spec_helper'

#describe command('hostname') do
  #its(:stdout) { should contain( "#{property['inventory_hostname']}" ) }
#end

#describe file( property["my_name"] ) do # sample of playbook variable
  #it { should be_file }
#end

describe file( property["check_file_name"] ) do # sample of inventory variable
  it { should be_file }
end

