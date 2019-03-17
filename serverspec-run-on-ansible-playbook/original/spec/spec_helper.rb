require 'serverspec'
require 'net/ssh'
require 'winrm'
require 'yaml'

hostvars = YAML.load_file(ENV['HOST_VARS_PATH'])
set_property hostvars

if hostvars["ansible_connection"] == 'winrm'
#
# OS type: Windows / Connetion type: winrm
#
  set :backend, :winrm
  set :os, :family => 'windows'

  host = hostvars["ansible_ssh_host"]  || hostvars["ansible_host"]      || hostvars["inventory_hostname"]
  user = hostvars["ansible_ssh_user"]  || hostvars["ansible_user"]  
  port = hostvars["ansible_ssh_port"]  || hostvars["ansible_port"]    
  pass = hostvars["ansible_ssh_pass"]  || hostvars["ansible_password"]   

  endpoint = "http://#{host}:#{port}/wsman"

  winrm = ::WinRM::WinRMWebService.new(endpoint, :ssl, :user => user, :pass => pass, :basic_auth_only => true)
  winrm.set_timeout 300 # 5 minutes max timeout for any operation
  Specinfra.configuration.winrm = winrm

elsif hostvars["ansible_connection"] == 'local' || hostvars["ansible_ssh_host"] == 'localhost' || hostvars["ansible_host"] == 'localhost' || hostvars["inventory_hostname"] == 'localhost'
#
# OS type: UN*X / Connction type: local exec
#
 set :backend, :exec
else
#
# OS type: UN*X / Connction type: ssh
#
  set :backend, :ssh

  set :sudo_password, hostvars["ansible_ssh_pass"] || hostvars["ansible_password"]

  host = hostvars["ansible_ssh_host"] || hostvars["ansible_host"] || hostvars["inventory_hostname"]

  options = Net::SSH::Config.for(host)

  options[:user] ||= hostvars["ansible_ssh_user"]             || hostvars["ansible_user"]
  options[:port] ||= hostvars["ansible_ssh_port"]             || hostvars["ansible_port"]
  options[:keys] ||= hostvars["ansible_ssh_private_key_file"] || hostvars["ansible_private_key_file"]

  set :host,        options[:host_name] || host
  set :ssh_options, options

  # Disable sudo
  # set :disable_sudo, true

  # Set environment variables
  # set :env, :LANG => 'C', :LC_MESSAGES => 'C'

  # Set PATH
  # set :path, '/sbin:/usr/local/sbin:$PATH'
end
