require 'spec_helper'
require 'travis/scheduler/models/repository'
require 'travis/scheduler/models/repository/settings'

describe Repository do
  describe 'api_url' do
    let(:repo) { Repository.new(owner_name: 'travis-ci', name: 'travis-ci') }

    before :each do
      Travis.config.github.api_url = 'https://api.github.com'
    end

    it 'returns the api url for the repository' do
      repo.api_url.should == 'https://api.github.com/repos/travis-ci/travis-ci'
    end
  end

  describe 'source_url' do
    describe 'default source endpoint' do
      let(:repo) { Repository.new(owner_name: 'travis-ci', name: 'travis-ci') }

      before :each do
        Travis.config.github.source_host = nil
      end

      it 'returns the public git source url for a public repository' do
        repo.private = false
        repo.source_url.should == 'git://github.com/travis-ci/travis-ci.git'
      end

      it 'returns the private git source url for a private repository' do
        repo.private = true
        repo.source_url.should == 'git@github.com:travis-ci/travis-ci.git'
      end
    end

    describe 'custom source endpoint' do
      let(:repo) { Repository.new(owner_name: 'travis-ci', name: 'travis-ci') }

      before :each do
        Travis.config.github.source_host = 'localhost'
      end

      it 'returns the private git source url for a public repository' do
        repo.private = false
        repo.source_url.should == 'git@localhost:travis-ci/travis-ci.git'
      end

      it 'returns the private git source url for a private repository' do
        repo.private = true
        repo.source_url.should == 'git@localhost:travis-ci/travis-ci.git'
      end
    end
  end

  describe 'source_host' do
    before :each do
      Travis.config.github.stubs(:source_host).returns('localhost')
    end

    it 'returns the source_host name from Travis.config' do
      Repository.new.source_host.should == 'localhost'
    end
  end

  describe 'settings' do
    let(:repo) { Factory.create(:repository) }

    it 'adds repository_id to collection records' do
      env_var = repo.settings.env_vars.create(name: 'FOO')
      env_var.repository_id.should == repo.id
      repo.settings.save

      repo.reload.settings.env_vars.first.repository_id.should == repo.id
    end

    it "allows to set nil for settings" do
      repo.settings = nil
      repo.settings.to_hash.should == Repository::Settings.new.to_hash
    end

    it "allows to set settings as JSON string" do
      repo.settings = '{"maximum_number_of_builds": 44}'
      repo.settings.to_hash.should == Repository::Settings.new(maximum_number_of_builds: 44).to_hash
    end

    it "allows to set settings as a Hash" do
      repo.settings = { maximum_number_of_builds: 44}
      repo.settings.to_hash.should == Repository::Settings.new(maximum_number_of_builds: 44).to_hash
    end
  end
end