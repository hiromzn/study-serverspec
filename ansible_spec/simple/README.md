# sample code

- ansible-sample-tdd
  - URL: https://github.com/volanja/ansible-sample-tdd

# prepare

- auto login

  - user name of site.yml CAN ssh to localhost

# run

```
########################
# run from ansible
########################
$ ansible-playbook -i host site.yml

########################
# run from serverspec
########################
$ rake -T
rake serverspec:CHECK  # Run serverspec for CHECK

$ rake serverspec:CHECK
Run serverspec for CHECK to {"name"=>"localhost ansible_connection=local", "port"=>22, "uri"=>"localhost", "connection"=>"local"}
/opt/rubies/ruby-2.5.3/bin/ruby -I/home/hmizuno/.gem/ruby/2.5.3/gems/rspec-support-3.8.0/lib:/home/hmizuno/.gem/ruby/2.5.3/gems/rspec-core-3.8.0/lib /home/hmizuno/.gem/ruby/2.5.3/gems/rspec-core-3.8.0/exe/rspec --pattern roles/\{checkfile\}/spec/\*_spec.rb
.

Finished in 5.04 seconds (files took 1.17 seconds to load)
1 example, 0 failures


```
