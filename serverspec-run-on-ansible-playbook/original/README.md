# serverspec-run-on-ansible-playbook
+ Serverspec run on the ansible-playbook with Ansible's hostvars variables.
+ Description of the English version is expected to write later.
+ This README.md is Description for Japanese blog [qiita] (http://qiita.com/tbuchi888/items/2e2ab894b975823953aa).

## ServerspecをAnsibleのhostvars変数の値を使ってansible-playbook から実行する方法

## はじめに
+ ちょっと長目の記事です。また、説明など少し足りない部分もあるかもしれません。
+ コード一式は[https://github.com/tbuchi888/serverspec-run-on-ansible-playbook](https://github.com/tbuchi888/serverspec-run-on-ansible-playbook)に上げています。
+ githubでの英語版の説明は別途書く予定です。

## いままで
Ansibleのインベントリホスト（ターゲットホスト）に対してServerspecを実施する場合以下の方法があると思います。

|No.|方法|特徴|
|:-:|:-:|:-:|
|1|Ansibleのcommandやshellモジュールから、`rake spec`や`rake spec:hogerole`などServerspecを直接呼び出す方法|AnsibleとServerspecで別々にinventoryやhostvarsを管理する必要がある|
|2 |[ansible_spec](https://github.com/volanja/ansible_spec)などAnsibleとServerspecのパーサーを使う方法|ansible_specはGemでインストール後に、指定の形式（Inventoryファイルやロールなど、ベストプラクティスディレクトリ構成に近い）をとれば、Ansibleのファイルを利用して、容易にAnsibleのロール単位でテスト実行が可能で便利.ただし、Ansible側でロール構成が必要なことやインベントリファイル内のVariablesが未だ対応していない等の制約もある|
|3|[kitchen-ansible](https://github.com/neillturner/kitchen-ansible)や[molecule](https://github.com/metacloud/molecule/blob/master/docs/source/usage.rst)などを利用する|こちらは未検証ですが、Vagrantなどと連携して、テスト用のVMまで構築するイメージ|

### そこで
No.1に近い方法で、以下のAnsibleの`template`モジュールとServerspecのTipsなど基本機能を利用して　*「ServerspecをAnsibleのhostvars変数の値を使ってansible-playbook から実行する方法」*　を検討しました。

##### 参考にしたAnsibleとServerspecの基本機能やTips

+ Ansible
  + [FAQ: In a template, get all the IPs of all machines in a group](https://support.ansible.com/hc/en-us/articles/201957817-In-a-template-get-all-the-IPs-of-all-machines-in-a-group)
+ Serverspec 
  + [advanced tips: How to use host specific properties](http://serverspec.org/advanced_tips.html)

### 事前準備
#### AnsibleとServerspec実行 HOSTマシン
1. CentOS67 AnsibleとServerspecをインストール済み　*1台を用意

#### サンプルのインベントリホスト（ターゲットホスト）マシン
[こちらを参考に作ります](http://qiita.com/tbuchi888/items/c60025d68c8b49dbf6d1)

1. Windows2012R2 IISインストール済み *2台を用意
2. CentOS67 httpdインストール済み *2台を用意
3. 上記HOSTマシン *1

#### Ansible側
1. インベントリホスト（実行対象ホスト）毎のhostvarsをYAML形式でダンプするjinjya2のtemplateファイルを`templates/dump_variables.j2`として作成
2. 以下をAnsible実行ホストマシンのlocalで実施するplaybook `spec.yml` を作成
  1. templateモジュールを利用して、インベントリホストのhostvarsの情報をYAML形式でカレントディレクトリに保存する
  1. shellモジュールで上記ファイルと、serverspecのロール名を引数にしてserverspecを実行する
  1. debugモジュールでserverspec実行結果を表示 

dump_variables.j2

``` dump_variables.j2
{{ hostvars[inventory_hostname] | to_yaml }}
#{{ vars | to_yaml }} 
```

spec.yml

``` spec.yml
---
- hosts: all
  gather_facts: no
  vars:
    spec_vars_dir:  "{{playbook_dir}}/spec_vars"
    host_vars_path: "{{spec_vars_dir}}/hostvars_{{inventory_hostname}}.yml"
  tasks:
   - name: create "{{spec_vars_dir}}" directory
     file:
       path: "{{spec_vars_dir}}"
       state: directory 
     delegate_to: localhost
   - name: "dump_variables hostvars to yml"
     template:
       src: templates/dump_variables.j2
       dest: "{{host_vars_path}}"
     delegate_to: localhost
   - name: rake serverspec with hostvars
     shell: HOST_VARS_PATH={{host_vars_path}} rake serverspec:{{spec_role}}
     register: raw_result
     delegate_to: localhost
   - name: stdout of serverspec
     debug: var=raw_result.stdout_lines
```

#### サンプルのAnsibleのインベントリファイル　
hosts

``` hosts
[win]
win2012-iis01 spec_role=AAA ansible_host=192.168.33.51
win2012-iis02 spec_role=BBB ansible_host=192.168.33.52

[centos]
centos6-httpd01 spec_role=AAA ansible_host=192.168.33.41
centos6-httpd02 spec_role=BBB ansible_host=192.168.33.42
myansible spec_role=BBB ansible_host=localhost

[win:vars]
ansible_connection=winrm
ansible_port=5985
ansible_user=vagrant
ansible_password=vagrant
#web_service_name="World Wide Web Publishing Service"
web_service_name="W3SVC"

[centos:vars]
ansible_user=vagrant
ansible_private_key_file=~/.ssh/id_rsa
web_service_name=httpd
```

#### Serverspec側
1. `Rakefile`を以下通りカスタマイズ
2. `spec_helper.rb`を以下通りカスタマイズ、合わせてマルチOS（windows/un*x）、マルチコネクション(ssh/local/winrm)対応も実施
3. テスト用のspecファイルを準備

Rakefile

``` Rakefile
require 'rake'
require 'rspec/core/rake_task'
require 'yaml'

hostvars = YAML.load_file(ENV['HOST_VARS_PATH'])

namespace :serverspec do
  desc "Run serverspec for #{hostvars["spec_role"]}"
  RSpec::Core::RakeTask.new(hostvars["spec_role"].to_sym) do |t|
    t.pattern = "spec/#{hostvars["spec_role"]}/*_spec.rb"
  end
end
```

spec_helper.rb

``` spec_helper.rb
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
```

#### サンプルのServersepcのロールとspecファイル

+ ROLE:AAA
  + spec/AAA/sample_spec.rb
  + Ansibleのhostvarsに設定した変数`web_service_name`のサービス状態を確認するサンプル

sample_spec.rb

``` sample_spec.rb
require 'spec_helper'

describe service( property["web_service_name"] ) do
  it { should be_enabled }
  it { should be_running }
end
```

+ ROLE:BBB
  + spec/BBB/sample_spec.rb
  + Ansibleのインベントリファイルの`inventory_hostname`をホスト名として含んでいるか確認するサンプル

sample_spec.rb

``` sample_spec.rb
require 'spec_helper'

describe command('hostname') do
  its(:stdout) { should contain( "#{property['inventory_hostname']}" ) }
end
```

### Directory構成

```
├── README.md
├── Rakefile                # Sererspec：カスタマイズしたもの
├── hosts                   # Ansible：  サンプルのインベントリファイル
├── spec
│   ├── AAA                 # Sererspec：サンプルのロール名
│   │   └── sample_spec.rb  # Sererspec：サンプルのspecファイル
│   ├── BBB                 # Sererspec：サンプルのロール名
│   │   └── sample_spec.rb  # Sererspec：サンプルのspecファイル
│   └── spec_helper.rb      # Sererspec：カスタマイズしたもの
├── spec.yml                # Ansible：  カスタマイズしたPlaybook
├── spec_vars               # Ansible：  playbook実行時に作成
│   ├── hostvars_centos6-httpd01.yml 
│   ├── hostvars_centos6-httpd02.yml
│   ├── hostvars_myansible.yml
│   ├── hostvars_mygitlab.yml
│   ├── hostvars_win2012-iis01.yml
│   └── hostvars_win2012-iis02.yml
└── templates               # Ansible：  hostvarsをダンプjinjya2テンプレート
    └── dump_variables.j2

```

### 実行結果

```
[vagrant@myansible work2]$ ansible-playbook -i hosts spec.yml

PLAY [all] *********************************************************************

TASK [create "/opt/work2/spec_vars" directory] *********************************
ok: [win2012-iis01 -> localhost]
ok: [win2012-iis02 -> localhost]
ok: [centos6-httpd01 -> localhost]
ok: [centos6-httpd02 -> localhost]
ok: [myansible -> localhost]

TASK [dump_variables hostvars to yml] ******************************************
changed: [win2012-iis02 -> localhost]
changed: [win2012-iis01 -> localhost]
changed: [centos6-httpd02 -> localhost]
changed: [centos6-httpd01 -> localhost]
changed: [myansible -> localhost]

TASK [rake serverspec with hostvars] *******************************************
changed: [myansible -> localhost]
changed: [centos6-httpd01 -> localhost]
changed: [centos6-httpd02 -> localhost]
changed: [win2012-iis02 -> localhost]
changed: [win2012-iis01 -> localhost]

TASK [stdout of serverspec] ****************************************************
ok: [win2012-iis01] => {
    "raw_result.stdout_lines": [
        "/home/vagrant/.rbenv/versions/2.2.0/bin/ruby -I/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-support-3.4.1/lib:/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/lib /home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/exe/rspec --pattern spec/AAA/\\*_spec.rb", 
        "", 
        "Service \"W3SVC\"", 
        " WARN  WinRM::WinRMWebService : WinRM::WinRMWebService#run_powershell_script is deprecated. Use WinRM::CommandExecutor#run_powershell_script instead", 
        "  should be enabled", 
        " WARN  WinRM::WinRMWebService : WinRM::WinRMWebService#run_powershell_script is deprecated. Use WinRM::CommandExecutor#run_powershell_script instead", 
        "  should be running", 
        "", 
        "Finished in 8.53 seconds (files took 5.67 seconds to load)", 
        "2 examples, 0 failures"
    ]
}
ok: [centos6-httpd01] => {
    "raw_result.stdout_lines": [
        "/home/vagrant/.rbenv/versions/2.2.0/bin/ruby -I/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-support-3.4.1/lib:/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/lib /home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/exe/rspec --pattern spec/AAA/\\*_spec.rb", 
        "", 
        "Service \"httpd\"", 
        "  should be enabled", 
        "  should be running", 
        "", 
        "Finished in 2.99 seconds (files took 3.3 seconds to load)", 
        "2 examples, 0 failures"
    ]
}
ok: [win2012-iis02] => {
    "raw_result.stdout_lines": [
        "/home/vagrant/.rbenv/versions/2.2.0/bin/ruby -I/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-support-3.4.1/lib:/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/lib /home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/exe/rspec --pattern spec/BBB/\\*_spec.rb", 
        "", 
        "Command \"hostname\"", 
        "  stdout", 
        " WARN  WinRM::WinRMWebService : WinRM::WinRMWebService#run_powershell_script is deprecated. Use WinRM::CommandExecutor#run_powershell_script instead", 
        "    should contain \"win2012-iis02\"", 
        "", 
        "Finished in 5.32 seconds (files took 5.65 seconds to load)", 
        "1 example, 0 failures"
    ]
}
ok: [centos6-httpd02] => {
    "raw_result.stdout_lines": [
        "/home/vagrant/.rbenv/versions/2.2.0/bin/ruby -I/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-support-3.4.1/lib:/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/lib /home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/exe/rspec --pattern spec/BBB/\\*_spec.rb", 
        "", 
        "Command \"hostname\"", 
        "  stdout", 
        "    should contain \"centos6-httpd02\"", 
        "", 
        "Finished in 3.74 seconds (files took 4.73 seconds to load)", 
        "1 example, 0 failures"
    ]
}
ok: [myansible] => {
    "raw_result.stdout_lines": [
        "/home/vagrant/.rbenv/versions/2.2.0/bin/ruby -I/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-support-3.4.1/lib:/home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/lib /home/vagrant/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/rspec-core-3.4.3/exe/rspec --pattern spec/BBB/\\*_spec.rb", 
        "", 
        "Command \"hostname\"", 
        "  stdout", 
        "    should contain \"myansible\"", 
        "", 
        "Finished in 1.9 seconds (files took 3.59 seconds to load)", 
        "1 example, 0 failures"
    ]
}

PLAY RECAP *********************************************************************
centos6-httpd01            : ok=4    changed=2    unreachable=0    failed=0   
centos6-httpd02            : ok=4    changed=2    unreachable=0    failed=0   
myansible                  : ok=4    changed=2    unreachable=0    failed=0   
win2012-iis01              : ok=4    changed=2    unreachable=0    failed=0   
win2012-iis02              : ok=4    changed=2    unreachable=0    failed=0   

[vagrant@myansible work2]$ 
```

## 参考：AnsibleとServerspec実行環境

```
[vagrant@myansible work2]$ ansible --version
ansible 2.1.0 (devel f99ed97c40) last updated 2016/02/28 15:58:58 (GMT +100)
  lib/ansible/modules/core: (detached HEAD 45367c3d09) last updated 2016/02/28 15:59:27 (GMT +100)
  lib/ansible/modules/extras: (detached HEAD 479f99678b) last updated 2016/02/28 15:59:53 (GMT +100)
  config file = /etc/ansible/ansible.cfg
  configured module search path = Default w/o overrides
[vagrant@myansible work2]$ ruby -v
ruby 2.2.0p0 (2014-12-25 revision 49005) [x86_64-linux]
[vagrant@myansible work2]$ rbenv -v
rbenv 1.0.0-19-g29b4da7
[vagrant@myansible work2]$ gem list

*** LOCAL GEMS ***

ansible_spec (0.2.9)
bigdecimal (1.2.6)
builder (3.2.2)
bundler (1.11.2)
diff-lcs (1.2.5)
docile (1.1.5)
ffi (1.9.10)
gssapi (1.2.0)
gyoku (1.3.1)
hostlist_expression (0.2.1)
httpclient (2.7.1)
io-console (0.4.3)
json (1.8.3, 1.8.1)
little-plugger (1.1.4)
logging (2.0.0)
minitest (5.4.3)
multi_json (1.11.2)
net-scp (1.2.1)
net-ssh (3.0.2)
net-telnet (0.1.1)
nori (2.6.0)
oj (2.14.6)
power_assert (0.2.2)
psych (2.0.8)
rake (10.5.0, 10.4.2)
rdoc (4.2.0)
rspec (3.4.0)
rspec-core (3.4.3)
rspec-expectations (3.4.0)
rspec-its (1.2.0)
rspec-mocks (3.4.1)
rspec-support (3.4.1)
rubyntlm (0.6.0)
serverspec (2.30.0)
sfl (2.2)
simplecov (0.11.2)
simplecov-html (0.10.0)
specinfra (2.52.0)
test-unit (3.0.8)
winrm (1.7.2)
[vagrant@myansible work2]$ 
```
