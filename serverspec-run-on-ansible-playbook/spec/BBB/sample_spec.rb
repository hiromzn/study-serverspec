require 'spec_helper'

describe command('hostname') do
  its(:stdout) { should contain( "#{property['inventory_hostname']}" ) }
end
