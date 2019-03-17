require 'spec_helper'

describe service( property["web_service_name"] ) do
  it { should be_enabled }
  it { should be_running }
end


#describe port( property["ansible_port"].to_i ) do
#  it { should be_listening }
#end
